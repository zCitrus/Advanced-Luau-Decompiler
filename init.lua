local Luau = loadstring(game:HttpGet("https://raw.githubusercontent.com/USERNAME/REPO_NAME/main/Luau.lua"))() or require(script.Luau)
local Reader = loadstring(game:HttpGet("https://raw.githubusercontent.com/USERNAME/REPO_NAME/main/Reader.lua"))() or require(script.Reader)

local Decompiler = {}
local bit = bit32 or bit

local function formatConstant(k)
    if type(k) == "string" then
        return string.format("%q", k)
    elseif type(k) == "number" or type(k) == "boolean" then
        return tostring(k)
    elseif k == nil then
        return "nil"
    end
    return tostring(k)
end

function Decompiler.decompile(bytecode)
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

    -- 3. Protos
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
                constants[i] = "Import(" .. tostring(reader:ReadUInt32()) .. ")"
            elseif ktype == Luau.ConstantType.TABLE then
                local keyCount = reader:ReadVarInt()
                local keys = {}
                for k = 1, keyCount do
                    keys[k] = reader:ReadVarInt()
                end
                constants[i] = "TableShape(size=" .. tostring(keyCount) .. ")"
            elseif ktype == Luau.ConstantType.CLOSURE then
                constants[i] = "Closure(proto=" .. tostring(reader:ReadVarInt()) .. ")"
            elseif ktype == Luau.ConstantType.VECTOR then
                local x, y, z, w = reader:ReadFloat(), reader:ReadFloat(), reader:ReadFloat(), reader:ReadFloat()
                constants[i] = string.format("Vector(%f, %f, %f, %f)", x, y, z, w)
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
            local intervals = bit.rshift(sizecode - 1, linegaplog2) + 1
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

    -- 4. Disassemble Output Generation
    local output = {}
    table.insert(output, string.format("-- Advanced Decompiler Patched (Luau Bytecode v%d, TypeTable v%d)", version, typeVersion))
    table.insert(output, string.format("-- Protos: %d | Strings: %d | Main: Proto %d\n", #protos, #stringTable, mainProtoId))

    for _, proto in ipairs(protos) do
        table.insert(output, string.format("PROTO [%d] '%s':", proto.id, proto.debugname))
        table.insert(output, string.format("  .params %d | .upvalues %d | .stack %d", proto.numparams, proto.numupvalues, proto.maxstacksize))

        local pc = 1
        local code = proto.code
        while pc <= #code do
            local inst = code[pc]
            local op = bit.band(inst, 0xFF)
            local a = bit.band(bit.rshift(inst, 8), 0xFF)
            local b = bit.band(bit.rshift(inst, 16), 0xFF)
            local c = bit.band(bit.rshift(inst, 24), 0xFF)
            local d = bit.rshift(inst, 16)
            if d >= 0x8000 then d = d - 0x10000 end

            local opInfo = Luau.OpCodes[op] or { name = "OP_" .. tostring(op), format = Luau.FORMAT_ABC, aux = false }
            local aux = (opInfo.aux and pc < #code) and code[pc + 1] or nil

            local desc = ""
            if opInfo.format == Luau.FORMAT_ABC then
                desc = string.format("R%d, R%d, R%d", a, b, c)
            elseif opInfo.format == Luau.FORMAT_AD then
                desc = string.format("R%d, %d", a, d)
            elseif opInfo.format == Luau.FORMAT_E then
                desc = tostring(bit.rshift(inst, 8))
            end

            if aux then
                desc = desc .. string.format(" [AUX: %d]", aux)
            end

            -- Constant Annotations
            if (opInfo.name == "LOADK" or opInfo.name == "DUPTABLE") and proto.constants[d + 1] ~= nil then
                desc = desc .. " ; " .. formatConstant(proto.constants[d + 1])
            elseif (opInfo.name == "GETGLOBAL" or opInfo.name == "SETGLOBAL" or opInfo.name == "GETTABLEKS" or opInfo.name == "SETTABLEKS" or opInfo.name == "NAMECALL") and aux and proto.constants[aux + 1] ~= nil then
                desc = desc .. " ; " .. formatConstant(proto.constants[aux + 1])
            end

            table.insert(output, string.format("    [%04d] %-15s %s", pc - 1, opInfo.name, desc))
            pc = pc + (opInfo.aux and 2 or 1)
        end
        table.insert(output, "")
    end

    return table.concat(output, "\n")
end

return Decompiler
