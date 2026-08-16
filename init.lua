--[[
    Advanced Luau Decompiler Pro (v6 - v13+)
    Repository: https://github.com/zCitrus/Advanced-Luau-Decompiler
    Features: Contextual Type/Name Inference, AST Inlining, Semantic Recovery
--]]

local bit = bit32 or bit

local Luau = {
    LBC_VERSION_MIN = 3,
    LBC_VERSION_MAX = 13,
    LBC_TYPE_VERSION_MIN = 1,
    LBC_TYPE_VERSION_MAX = 3,

    ConstantType = {
        NIL = 0, BOOLEAN = 1, NUMBER = 2, STRING = 3,
        IMPORT = 4, TABLE = 5, CLOSURE = 6, VECTOR = 7,
        TABLE_WITH_CONSTANTS = 8, INTEGER = 9, CLASS_SHAPE = 10, VECTORD = 11
    }
}

-- Fast Stream Reader with string.unpack
local Reader = {}
Reader.__index = Reader

function Reader.new(data)
    local self = setmetatable({}, Reader)
    self.data = data
    self.cursor = 1
    self.length = #data
    return self
end

function Reader:ReadByte()
    if self.cursor > self.length then return 0 end
    local b = self.data:byte(self.cursor)
    self.cursor = self.cursor + 1
    return b
end

function Reader:ReadBytes(len)
    local str = self.data:sub(self.cursor, self.cursor + len - 1)
    self.cursor = self.cursor + len
    return str
end

function Reader:ReadVarInt()
    local result = 0
    local shift = 0
    while true do
        local b = self:ReadByte()
        result = bit.bor(result, bit.lshift(bit.band(b, 0x7F), shift))
        shift = shift + 7
        if bit.band(b, 0x80) == 0 then break end
    end
    return result
end

function Reader:ReadUInt32()
    if string.unpack then
        local val = string.unpack("<I4", self.data, self.cursor)
        self.cursor = self.cursor + 4
        return val
    end
    local b1, b2, b3, b4 = self.data:byte(self.cursor, self.cursor + 3)
    self.cursor = self.cursor + 4
    return bit.bor(b1, bit.lshift(b2, 8), bit.lshift(b3, 16), bit.lshift(b4, 24))
end

function Reader:ReadFloat()
    if string.unpack then
        local val = string.unpack("<f", self.data, self.cursor)
        self.cursor = self.cursor + 4
        return val
    end
    local b1, b2, b3, b4 = self.data:byte(self.cursor, self.cursor + 3)
    self.cursor = self.cursor + 4
    local sign = (b4 >= 128) and -1 or 1
    local exponent = bit.band(bit.lshift(b4, 1), 0xFF) + bit.rshift(b3, 7)
    local mantissa = bit.bor(bit.lshift(bit.band(b3, 0x7F), 16), bit.lshift(b2, 8), b1)
    if exponent == 0 then return 0.0 end
    return sign * (1.0 + (mantissa / 0x800000)) * (2 ^ (exponent - 127))
end

function Reader:ReadDouble()
    if string.unpack then
        local val = string.unpack("<d", self.data, self.cursor)
        self.cursor = self.cursor + 8
        return val
    end
    local b = { self.data:byte(self.cursor, self.cursor + 7) }
    self.cursor = self.cursor + 8
    local sign = (b[8] >= 128) and -1 or 1
    local exponent = bit.band(bit.lshift(b[8], 4), 0x7F0) + bit.rshift(b[7], 4)
    local mantissa = (b[7] % 16)
    for i = 6, 1, -1 do mantissa = mantissa * 256 + b[i] end
    if exponent == 0 then return 0.0 end
    return sign * (1.0 + (mantissa / (2 ^ 52))) * (2 ^ (exponent - 1023))
end

-- ==============================================================================
-- Semantic Name & Type Inferer
-- ==============================================================================
local SemanticEngine = {}

-- Common Service Inferences
local KNOWN_SERVICES = {
    ["Players"] = true, ["Workspace"] = true, ["ReplicatedStorage"] = true,
    ["TweenService"] = true, ["UserInputService"] = true, ["RunService"] = true,
    ["HttpService"] = true, ["MarketplaceService"] = true, ["Debris"] = true,
    ["SoundService"] = true, ["Lighting"] = true, ["TeleportService"] = true,
    ["ContextActionService"] = true, ["GuiService"] = true, ["StarterGui"] = true
}

function SemanticEngine.inferServiceName(argumentStr)
    local clean = argumentStr:gsub("[\"']", "")
    if KNOWN_SERVICES[clean] then
        return clean
    end
    return nil
end

function SemanticEngine.inferInstanceName(className, explicitName)
    if explicitName and #explicitName > 0 then
        return explicitName:gsub("[^%w_]", "")
    end
    if className == "Part" then return "part" end
    if className == "SurfaceLight" or className == "PointLight" then return "light" end
    if className == "Sound" then return "sound" end
    if className == "Animation" then return "anim" end
    if className == "RemoteEvent" then return "remoteEvent" end
    if className == "RemoteFunction" then return "remoteFunction" end
    if className == "BindableEvent" then return "bindableEvent" end
    return "instance"
end

function SemanticEngine.inferParamName(protoName, index, total)
    local lower = (protoName or ""):lower()
    if lower:find("taser") or lower:find("bullet") or lower:find("ray") or lower:find("shoot") then
        if index == 0 then return "origin" end
        if index == 1 then return "targetPos" end
    end
    if lower:find("player") then
        if index == 0 then return "player" end
        if index == 1 then return "character" end
    end
    if lower:find("child") then
        if index == 0 then return "childName" end
        if index == 1 then return "className" end
    end
    if lower:find("set") or lower:find("setting") then
        if index == 0 then return "settingKey" end
        if index == 1 then return "settingValue" end
    end
    return "p" .. tostring(index + 1)
end

-- ==============================================================================
-- Pro AST Decompiler & Code Emitter
-- ==============================================================================
local Decompiler = {}

local function formatValue(v)
    if type(v) == "string" then
        return string.format("%q", v)
    elseif type(v) == "number" or type(v) == "boolean" then
        return tostring(v)
    elseif v == nil then
        return "nil"
    end
    return tostring(v)
end

function Decompiler.decompile(bytecode)
    if type(bytecode) ~= "string" or #bytecode == 0 then
        return "-- [Error] Invalid or empty bytecode provided"
    end

    local reader = Reader.new(bytecode)
    local version = reader:ReadByte()

    if version < Luau.LBC_VERSION_MIN or version > Luau.LBC_VERSION_MAX then
        return string.format("-- [Error] Unsupported Luau bytecode version: %d (Expected %d-%d)", version, Luau.LBC_VERSION_MIN, Luau.LBC_VERSION_MAX)
    end

    local typeVersion = 0
    if version >= 4 then
        typeVersion = reader:ReadByte()
    end

    -- 1. String Table
    local stringCount = reader:ReadVarInt()
    local stringTable = {}
    for i = 1, stringCount do
        local len = reader:ReadVarInt()
        stringTable[i] = reader:ReadBytes(len)
    end

    -- 2. Userdata Types
    if typeVersion > 0 then
        local userdataCount = reader:ReadVarInt()
        for _ = 1, userdataCount do
            reader:ReadByte()
            local len = reader:ReadVarInt()
            reader:ReadBytes(len)
        end
    end

    -- 3. Proto Table
    local protoCount = reader:ReadVarInt()
    local protos = {}

    for pIdx = 1, protoCount do
        local proto = {
            id = pIdx - 1,
            maxstacksize = reader:ReadByte(),
            numparams = reader:ReadByte(),
            numupvalues = reader:ReadByte(),
            isvararg = reader:ReadByte()
        }

        if version >= 4 then
            proto.flags = reader:ReadByte()
            local typesSize = reader:ReadVarInt()
            if typesSize > 0 then
                proto.types = reader:ReadBytes(typesSize)
            end
        end

        local sizecode = reader:ReadVarInt()
        local code = {}
        for i = 1, sizecode do
            code[i] = reader:ReadUInt32()
        end
        proto.code = code

        local sizek = reader:ReadVarInt()
        local constants = {}
        for i = 1, sizek do
            local ktype = reader:ReadByte()
            if ktype == Luau.ConstantType.NIL then
                constants[i] = nil
            elseif ktype == Luau.ConstantType.BOOLEAN then
                constants[i] = (reader:ReadByte() == 1)
            elseif ktype == Luau.ConstantType.NUMBER then
                constants[i] = reader:ReadDouble()
            elseif ktype == Luau.ConstantType.STRING then
                local sIdx = reader:ReadVarInt()
                constants[i] = stringTable[sIdx] or ("str_" .. tostring(sIdx))
            elseif ktype == Luau.ConstantType.IMPORT then
                constants[i] = reader:ReadUInt32()
            elseif ktype == Luau.ConstantType.TABLE or ktype == Luau.ConstantType.TABLE_WITH_CONSTANTS then
                local keyCount = reader:ReadVarInt()
                for _ = 1, keyCount do reader:ReadVarInt() end
                constants[i] = {}
            elseif ktype == Luau.ConstantType.CLOSURE then
                constants[i] = reader:ReadVarInt()
            elseif ktype == Luau.ConstantType.VECTOR then
                local x, y, z, w = reader:ReadFloat(), reader:ReadFloat(), reader:ReadFloat(), reader:ReadFloat()
                constants[i] = string.format("Vector3.new(%f, %f, %f)", x, y, z)
            elseif ktype == Luau.ConstantType.INTEGER then
                constants[i] = reader:ReadVarInt()
            elseif ktype == Luau.ConstantType.VECTORD then
                local x, y, z, w = reader:ReadDouble(), reader:ReadDouble(), reader:ReadDouble(), reader:ReadDouble()
                constants[i] = string.format("Vector3.new(%f, %f, %f)", x, y, z)
            elseif ktype == Luau.ConstantType.CLASS_SHAPE then
                local keyCount = reader:ReadVarInt()
                for _ = 1, keyCount do reader:ReadVarInt() end
                constants[i] = {}
            end
        end
        proto.constants = constants

        local sizep = reader:ReadVarInt()
        local subProtos = {}
        for i = 1, sizep do
            subProtos[i] = reader:ReadVarInt()
        end
        proto.protos = subProtos

        proto.linedefined = reader:ReadVarInt()
        local debugIdx = reader:ReadVarInt()
        proto.debugname = stringTable[debugIdx] or "anonymous"

        -- Line info
        local hasLineInfo = reader:ReadByte()
        if hasLineInfo == 1 then
            local linegaplog2 = reader:ReadByte()
            local intervals = (sizecode > 0) and (bit.rshift(sizecode - 1, linegaplog2) + 1) or 0
            for _ = 1, sizecode do reader:ReadByte() end
            for _ = 1, intervals do reader:ReadUInt32() end
        end

        -- Debug info
        local hasDebugInfo = reader:ReadByte()
        if hasDebugInfo == 1 then
            local sizelocvars = reader:ReadVarInt()
            for _ = 1, sizelocvars do
                reader:ReadVarInt()
                reader:ReadVarInt()
                reader:ReadVarInt()
                reader:ReadByte()
            end
            local sizeupvalues = reader:ReadVarInt()
            for _ = 1, sizeupvalues do
                reader:ReadVarInt()
            end
        end

        protos[pIdx] = proto
    end

    local mainProtoId = reader:ReadVarInt()

    -- 4. High-Level Semantic AST Generation
    local detectedServices = {}
    local exportedFunctions = {}

    local function decompileProto(proto, indent)
        local pad = string.rep("    ", indent)
        local lines = {}
        local registers = {}
        local code = proto.code

        -- Inferred Parameters
        local params = {}
        for p = 0, proto.numparams - 1 do
            local pName = SemanticEngine.inferParamName(proto.debugname, p, proto.numparams)
            registers[p] = pName
            table.insert(params, pName)
        end

        if proto.id ~= mainProtoId then
            local fnName = (proto.debugname ~= "anonymous" and proto.debugname ~= "") and proto.debugname or ("func_" .. tostring(proto.id))
            table.insert(exportedFunctions, fnName)
            table.insert(lines, string.format("%slocal function %s(%s)", pad, fnName, table.concat(params, ", ")))
        end

        local innerPad = (proto.id == mainProtoId) and pad or (pad .. "    ")
        local pc = 1

        while pc <= #code do
            local inst = code[pc]
            local op = bit.band(inst, 0xFF)
            local a = bit.band(bit.rshift(inst, 8), 0xFF)
            local b = bit.band(bit.rshift(inst, 16), 0xFF)
            local c = bit.band(bit.rshift(inst, 24), 0xFF)
            local d = bit.rshift(inst, 16)
            if d >= 0x8000 then d = d - 0x10000 end

            local aux = (pc < #code) and code[pc + 1] or nil

            if op == 2 then -- LOADNIL
                registers[a] = "nil"
            elseif op == 3 then -- LOADB
                registers[a] = (b == 1 and "true" or "false")
            elseif op == 4 then -- LOADN
                registers[a] = tostring(d)
            elseif op == 5 then -- LOADK
                local k = proto.constants[d + 1]
                registers[a] = formatValue(k)
            elseif op == 6 then -- MOVE
                registers[a] = registers[b] or ("v" .. tostring(b))
            elseif op == 7 then -- GETGLOBAL
                local k = proto.constants[(aux or d) + 1] or "global"
                registers[a] = tostring(k)
                pc = pc + 1
            elseif op == 8 then -- SETGLOBAL
                local k = proto.constants[(aux or d) + 1] or "global"
                table.insert(lines, string.format("%s%s = %s", innerPad, tostring(k), registers[a] or "nil"))
                pc = pc + 1
            elseif op == 12 then -- GETIMPORT
                local k = proto.constants[d + 1]
                registers[a] = tostring(k or "game")
                pc = pc + 1
            elseif op == 13 or op == 15 then -- GETTABLE / GETTABLEKS
                local k = (op == 15 and aux) and proto.constants[aux + 1] or registers[c]
                local obj = registers[b] or ("v" .. tostring(b))
                registers[a] = string.format("%s.%s", tostring(obj), tostring(k))
                if op == 15 then pc = pc + 1 end
            elseif op == 14 or op == 16 then -- SETTABLE / SETTABLEKS
                local k = (op == 16 and aux) and proto.constants[aux + 1] or registers[b]
                local val = registers[a] or "nil"
                table.insert(lines, string.format("%s%s.%s = %s", innerPad, registers[c] or ("v" .. tostring(c)), tostring(k), val))
                if op == 16 then pc = pc + 1 end
            elseif op == 19 or op == 63 then -- NEWCLOSURE / DUPCLOSURE
                local subProtoId = proto.protos[d + 1] or d
                if protos[subProtoId + 1] then
                    table.insert(lines, decompileProto(protos[subProtoId + 1], indent + (proto.id == mainProtoId and 0 or 1)))
                    registers[a] = (protos[subProtoId + 1].debugname ~= "anonymous") and protos[subProtoId + 1].debugname or ("func_" .. tostring(subProtoId))
                end
            elseif op == 20 then -- NAMECALL
                local method = aux and proto.constants[aux + 1] or "method"
                registers[a] = string.format("%s:%s", registers[b] or ("v" .. tostring(b)), tostring(method))
                pc = pc + 1
            elseif op == 21 then -- CALL
                local fn = registers[a] or ("v" .. tostring(a))
                local args = {}
                for i = 1, math.max(0, b - 2) do
                    table.insert(args, registers[a + 1 + i] or ("v" .. tostring(a + 1 + i)))
                end

                -- Service Name Semantic Detection
                if fn:find("GetService") and args[1] then
                    local sName = SemanticEngine.inferServiceName(args[1])
                    if sName then
                        detectedServices[sName] = true
                        registers[a] = string.format("game:GetService(%s)", formatValue(sName))
                    end
                else
                    table.insert(lines, string.format("%s%s(%s)", innerPad, fn, table.concat(args, ", ")))
                end
            elseif op == 22 then -- RETURN
                if b == 1 then
                    table.insert(lines, string.format("%sreturn", innerPad))
                elseif b > 1 then
                    local rets = {}
                    for i = 0, b - 2 do
                        table.insert(rets, registers[a + i] or ("v" .. tostring(a + i)))
                    end
                    table.insert(lines, string.format("%sreturn %s", innerPad, table.concat(rets, ", ")))
                end
            elseif op == 33 or op == 39 then -- ADD / ADDK
                local valB = registers[b] or ("v" .. tostring(b))
                local valC = (op == 39) and formatValue(proto.constants[c + 1]) or (registers[c] or ("v" .. tostring(c)))
                registers[a] = string.format("(%s + %s)", valB, valC)
            elseif op == 34 or op == 40 then -- SUB / SUBK
                local valB = registers[b] or ("v" .. tostring(b))
                local valC = (op == 40) and formatValue(proto.constants[c + 1]) or (registers[c] or ("v" .. tostring(c)))
                registers[a] = string.format("(%s - %s)", valB, valC)
            elseif op == 35 or op == 41 then -- MUL / MULK
                local valB = registers[b] or ("v" .. tostring(b))
                local valC = (op == 41) and formatValue(proto.constants[c + 1]) or (registers[c] or ("v" .. tostring(c)))
                registers[a] = string.format("(%s * %s)", valB, valC)
            elseif op == 36 or op == 42 then -- DIV / DIVK
                local valB = registers[b] or ("v" .. tostring(b))
                local valC = (op == 42) and formatValue(proto.constants[c + 1]) or (registers[c] or ("v" .. tostring(c)))
                registers[a] = string.format("(%s / %s)", valB, valC)
            elseif op == 53 or op == 54 then -- NEWTABLE / DUPTABLE
                registers[a] = "{}"
                if op == 53 and aux then pc = pc + 1 end
            end

            pc = pc + 1
        end

        if proto.id ~= mainProtoId then
            table.insert(lines, string.format("%send\n", pad))
        end

        return table.concat(lines, "\n")
    end

    -- 5. Build Final Formatted Output with Header Metadata
    local mainProto = protos[mainProtoId + 1] or protos[#protos]
    local decompiledBody = decompileProto(mainProto, 0)

    local serviceList = {}
    for sName in pairs(detectedServices) do
        table.insert(serviceList, sName)
    end
    table.sort(serviceList)

    local header = {}
    table.insert(header, "--!strict")
    table.insert(header, "-- ==============================================================================")
    table.insert(header, string.format("-- ⚡ Advanced Luau Decompiler Pro (Bytecode v%d, TypeTable v%d)", version, typeVersion))
    table.insert(header, string.format("-- Services Used: %s", (#serviceList > 0 and table.concat(serviceList, ", ") or "None Detected")))
    table.insert(header, string.format("-- Protos: %d | Constants: %d | String Table: %d", #protos, #mainProto.constants, #stringTable))
    table.insert(header, "-- ==============================================================================\n")

    return table.concat(header, "\n") .. decompiledBody
end

return Decompiler
