--[[
    Luau Bytecode Definitions & Opcode Specifications (v3 - v6)
    Repository: https://github.com/zCitrus/Advanced-Luau-Decompiler
--]]

local Luau = {}

-- Version specifications
Luau.LBC_VERSION_MIN = 3
Luau.LBC_VERSION_MAX = 6
Luau.LBC_TYPE_VERSION_MIN = 1
Luau.LBC_TYPE_VERSION_MAX = 3

-- Constant types
Luau.ConstantType = {
    NIL = 0,
    BOOLEAN = 1,
    NUMBER = 2,
    STRING = 3,
    IMPORT = 4,
    TABLE = 5,
    CLOSURE = 6,
    VECTOR = 7
}

-- Instruction format types
Luau.FORMAT_ABC = 1
Luau.FORMAT_AD  = 2
Luau.FORMAT_E   = 3

-- Opcode Table
Luau.OpCodes = {
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
    [80] = { name = "IDIVK", format = 1, aux = false }
}

return Luau
