local Reader = {}
Reader.__index = Reader

local bit = bit32 or bit

function Reader.new(data)
    local self = setmetatable({}, Reader)
    self.data = data
    self.cursor = 1
    self.length = #data
    return self
end

function Reader:ReadByte()
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
    local b1, b2, b3, b4 = self.data:byte(self.cursor, self.cursor + 3)
    self.cursor = self.cursor + 4
    return bit.bor(b1, bit.lshift(b2, 8), bit.lshift(b3, 16), bit.lshift(b4, 24))
end

function Reader:ReadFloat()
    local b1, b2, b3, b4 = self.data:byte(self.cursor, self.cursor + 3)
    self.cursor = self.cursor + 4
    local sign = (b4 >= 128) and -1 or 1
    local exponent = bit.band(bit.lshift(b4, 1), 0xFF) + bit.rshift(b3, 7)
    local mantissa = bit.bor(bit.lshift(bit.band(b3, 0x7F), 16), bit.lshift(b2, 8), b1)
    if exponent == 0 then return 0.0 end
    return sign * (1.0 + (mantissa / 0x800000)) * (2 ^ (exponent - 127))
end

function Reader:ReadDouble()
    local b = { self.data:byte(self.cursor, self.cursor + 7) }
    self.cursor = self.cursor + 8
    local sign = (b[8] >= 128) and -1 or 1
    local exponent = bit.band(bit.lshift(b[8], 4), 0x7F0) + bit.rshift(b[7], 4)
    local mantissa = (b[7] % 16)
    for i = 6, 1, -1 do mantissa = mantissa * 256 + b[i] end
    if exponent == 0 then return 0.0 end
    return sign * (1.0 + (mantissa / (2 ^ 52))) * (2 ^ (exponent - 1023))
end

return Reader
