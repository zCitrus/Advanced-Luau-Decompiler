--[[
    Advanced Luau Decompiler (v9+ Modern Bytecode Engine)
    Repository: https://github.com/zCitrus/Advanced-Luau-Decompiler
    Supports: Luau Bytecode v3 to v13 (Roblox 2026 Compatible)
--]]

local bit = bit32 or bit

-- ==============================================================================
-- 1. Bytecode Specification & Opcode Tables (Synced with Canonical Luau)
-- ==============================================================================
local Luau = {
    LBC_VERSION_MIN = 3,
    LBC_VERSION_MAX = 13, -- Updated to support modern Version 9 - 13 bytecode
    LBC_TYPE_VERSION_MIN = 1,
    LBC_TYPE_VERSION_MAX = 3,

    ConstantType = {
        NIL = 0,
        BOOLEAN = 1,
        NUMBER = 2,
        STRING = 3,
        IMPORT = 4,
        TABLE = 5,
        CLOSURE = 6,
        VECTOR = 7,
        TABLE_WITH_CONSTANTS = 8,
        INTEGER = 9,
        CLASS_SHAPE = 10,
        VECTORD = 11
    },

    FORMAT_ABC = 1,
    FORMAT_AD  = 2,
    FORMAT_E   = 3,

    OpCodes = {
        [0]  = { name = "NOP", format = 1, aux = false },
        [1]  = { name = "BREAK", format = 1, aux = false },
        [2]  = { name = "LOADNIL", format = 2, aux = false },
        [3]  = { name = "LOADB", format = 1, aux = false },
        [4]  = { name = "LOADN", format = 2, aux = false },
        [5]  = { name = "LOADK", format = 2, aux = false },
        [6]  = { name = "MOVE", format = 2, aux = false },
        [7]  = { name = "GETGLOBAL", format = 2, aux = true },
        [8]  = { name = "SETGLOBAL", format = 2, aux = true },
        [9]  = { name = "GETUPVAL", format = 2, aux = false },
        [10] = { name = "SETUPVAL", format = 2, aux = false },
        [11] = { name = "CLOSEUPVALS", format = 2, aux = false },
        [12] = { name = "GETIMPORT", format = 2, aux = true },
        [13] = { name = "GETTABLE", format = 1, aux = false },
        [14] = { name = "SETTABLE", format = 1, aux = false },
        [15] = { name = "GETTABLEKS", format = 1, aux = true },
        [16] = { name = "SETTABLEKS", format = 1, aux = true },
        [17] = { name = "GETTABLEN", format = 1, aux = false },
        [18] = { name = "SETTABLEN", format = 1, aux = false },
        [19] = { name = "NEWCLOSURE", format = 2, aux = false },
        [20] = { name = "NAMECALL", format = 1, aux = true },
        [21] = { name = "CALL", format = 1, aux = false },
        [22] = { name = "RETURN", format = 1, aux = false },
        [23] = { name = "JUMP", format = 2, aux = false },
        [24] = { name = "JUMPBACK", format = 2, aux = false },
        [25] = { name = "JUMPIF", format = 2, aux = false },
        [26] = { name = "JUMPIFNOT", format = 2, aux = false },
        [27] = { name = "JUMPIFEQ", format = 2, aux = true },
        [28] = { name = "JUMPIFLE", format = 2, aux = true },
        [29] = { name = "JUMPIFLT", format = 2, aux = true },
        [30] = { name = "JUMPIFNOTEQ", format = 2, aux = true },
        [31] = { name = "JUMPIFNOTLE", format = 2, aux = true },
        [32] = { name = "JUMPIFNOTLT", format = 2, aux = true },
        [33] = { name = "ADD", format = 1, aux = false },
        [34] = { name = "SUB", format = 1, aux = false },
        [35] = { name = "MUL", format = 1, aux = false },
        [36] = { name = "DIV", format = 1, aux = false },
        [37] = { name = "MOD", format = 1, aux = false },
        [38] = { name = "POW", format = 1, aux = false },
        [39] = { name = "ADDK", format = 1, aux = false },
        [40] = { name = "SUBK", format = 1, aux = false },
        [41] = { name = "MULK", format = 1, aux = false },
        [42] = { name = "DIVK", format = 1, aux = false },
        [43] = { name = "MODK", format = 1, aux = false },
        [44] = { name = "POWK", format = 1, aux = false },
        [45] = { name = "AND", format = 1, aux = false },
        [46] = { name = "OR", format = 1, aux = false },
        [47] = { name = "ANDK", format = 1, aux = false },
        [48] = { name = "ORK", format = 1, aux = false },
        [49] = { name = "CONCAT", format = 1, aux = false },
        [50] = { name = "NOT", format = 2, aux = false },
        [51] = { name = "MINUS", format = 2, aux = false },
        [52] = { name = "LENGTH", format = 2, aux = false },
        [53] = { name = "NEWTABLE", format = 1, aux = true },
        [54] = { name = "DUPTABLE", format = 2, aux = false },
        [55] = { name = "SETLIST", format = 1, aux = true },
        [56] = { name = "FORNPREP", format = 2, aux = false },
        [57] = { name = "FORNLOOP", format = 2, aux = false },
        [58] = { name = "FORGLOOP", format = 2, aux = true },
        [59] = { name = "FORGPREP_INEXT", format = 2, aux = false },
        [60] = { name = "FASTCALL3", format = 1, aux = true },
        [61] = { name = "FORGPREP_NEXT", format = 2, aux = false },
        [62] = { name = "GETVARARGS", format = 1, aux = false },
        [63] = { name = "DUPCLOSURE", format = 2, aux = false },
        [64] = { name = "BREAKPOINT", format = 1, aux = false },
        [65] = { name = "FALLTHROUGH", format = 1, aux = false },
        [66] = { name = "COVERAGE", format = 3, aux = false },
        [67] = { name = "CAPTURE", format = 2, aux = false },
        [68] = { name = "SUBRK", format = 1, aux = false },
        [69] = { name = "DIVRK", format = 1, aux = false },
        [70] = { name = "FASTCALL", format = 1, aux = false },
        [71] = { name = "FASTCALL1", format = 1, aux = false },
        [72] = { name = "FASTCALL2", format = 1, aux = true },
        [73] = { name = "FASTCALL2K", format = 1, aux = true },
        [74] = { name = "FORGPREP", format = 2, aux = false },
        [75] = { name = "JUMPXEQKNIL", format = 2, aux = true },
        [76] = { name = "JUMPXEQKB", format = 2, aux = true },
        [77] = { name = "JUMPXEQKN", format = 2, aux = true },
        [78] = { name = "JUMPXEQKS", format = 2, aux = true },
        [79] = { name = "IDIV", format = 1, aux = false },
        [80] = { name = "IDIVK", format = 1, aux = false },
        [81] = { name = "GETUDATAKS", format = 1, aux = true },
        [82] = { name = "SETUDATAKS", format = 1, aux = true },
        [83] = { name = "NAMECALLUDATA", format = 1, aux = true },
        [84] = { name = "NEWCLASSMEMBER", format = 1, aux = true },
        [85] = { name = "CALLFB", format = 1, aux = true },
        [86] = { name = "CMPPROTO", format = 2, aux = true },
        [87] = { name = "NEWCLASS", format = 1, aux = true }
    }
}

-- ==============================================================================
-- 2. Fast Binary Stream Reader
-- ==============================================================================
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
-- 3. Core Deserializer & Output Formatter
-- ==============================================================================
local Decompiler = {}

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
                constants[i] = "Import(" .. tostring(reader:ReadUInt32()) .. ")"
            elseif ktype == Luau.ConstantType.TABLE or ktype == Luau.ConstantType.TABLE_WITH_CONSTANTS then
                local keyCount = reader:ReadVarInt()
                for _ = 1, keyCount do
                    reader:ReadVarInt()
                end
                constants[i] = "TableShape(size=" .. tostring(keyCount) .. ")"
            elseif ktype == Luau.ConstantType.CLOSURE then
                constants[i] = "Closure(proto=" .. tostring(reader:ReadVarInt()) .. ")"
            elseif ktype == Luau.ConstantType.VECTOR then
                local x, y, z, w = reader:ReadFloat(), reader:ReadFloat(), reader:ReadFloat(), reader:ReadFloat()
                constants[i] = string.format("Vector(%f, %f, %f, %f)", x, y, z, w)
            elseif ktype == Luau.ConstantType.INTEGER then
                constants[i] = reader:ReadVarInt()
            elseif ktype == Luau.ConstantType.VECTORD then
                local x, y, z, w = reader:ReadDouble(), reader:ReadDouble(), reader:ReadDouble(), reader:ReadDouble()
                constants[i] = string.format("VectorD(%f, %f, %f, %f)", x, y, z, w)
            elseif ktype == Luau.ConstantType.CLASS_SHAPE then
                local keyCount = reader:ReadVarInt()
                for _ = 1, keyCount do
                    reader:ReadVarInt()
                end
                constants[i] = "ClassShape(size=" .. tostring(keyCount) .. ")"
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

    -- 4. Disassembly Output
    local output = {}
    table.insert(output, string.format("-- Advanced Luau Decompiler (Bytecode v%d, TypeTable v%d)", version, typeVersion))
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
            elseif opInfo.name == "NEWCLOSURE" and proto.protos[d + 1] ~= nil then
                local subId = proto.protos[d + 1]
                local subName = protos[subId + 1] and protos[subId + 1].debugname or "sub"
                desc = desc .. string.format(" ; Proto %d (%s)", subId, subName)
            end

            table.insert(output, string.format("    [%04d] %-15s %s", pc - 1, opInfo.name, desc))
            pc = pc + (opInfo.aux and 2 or 1)
        end
        table.insert(output, "")
    end

    return table.concat(output, "\n")
end

return Decompiler
