local Luau = {}

-- Supported Luau Bytecode Specifications
Luau.LBC_VERSION_MIN = 3
Luau.LBC_VERSION_MAX = 6
Luau.LBC_TYPE_VERSION_MIN = 1
Luau.LBC_TYPE_VERSION_MAX = 3

-- Luau Constant Types
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

-- Instruction Formats
Luau.FORMAT_ABC = 1
Luau.FORMAT_AD  = 2
Luau.FORMAT_E   = 3

-- Complete Modern Luau Opcode Table
Luau.OpCodes = {
    [0]  = { name = "NOP", format = Luau.FORMAT_ABC, aux = false },
    [1]  = { name = "BREAK", format = Luau.FORMAT_ABC, aux = false },
    [2]  = { name = "LOADNIL", format = Luau.FORMAT_AD, aux = false },
    [3]  = { name = "LOADB", format = Luau.FORMAT_ABC, aux = false },
    [4]  = { name = "LOADN", format = Luau.FORMAT_AD, aux = false },
    [5]  = { name = "LOADK", format = Luau.FORMAT_AD, aux = false },
    [6]  = { name = "MOVE", format = Luau.FORMAT_AD, aux = false },
    [7]  = { name = "GETGLOBAL", format = Luau.FORMAT_AD, aux = true },
    [8]  = { name = "SETGLOBAL", format = Luau.FORMAT_AD, aux = true },
    [9]  = { name = "GETUPVAL", format = Luau.FORMAT_AD, aux = false },
    [10] = { name = "SETUPVAL", format = Luau.FORMAT_AD, aux = false },
    [11] = { name = "CLOSEUPVALS", format = Luau.FORMAT_AD, aux = false },
    [12] = { name = "GETIMPORT", format = Luau.FORMAT_AD, aux = true },
    [13] = { name = "GETTABLE", format = Luau.FORMAT_ABC, aux = false },
    [14] = { name = "SETTABLE", format = Luau.FORMAT_ABC, aux = false },
    [15] = { name = "GETTABLEKS", format = Luau.FORMAT_ABC, aux = true },
    [16] = { name = "SETTABLEKS", format = Luau.FORMAT_ABC, aux = true },
    [17] = { name = "GETTABLEN", format = Luau.FORMAT_ABC, aux = false },
    [18] = { name = "SETTABLEN", format = Luau.FORMAT_ABC, aux = false },
    [19] = { name = "NEWCLOSURE", format = Luau.FORMAT_AD, aux = false },
    [20] = { name = "NAMECALL", format = Luau.FORMAT_ABC, aux = true },
    [21] = { name = "CALL", format = Luau.FORMAT_ABC, aux = false },
    [22] = { name = "RETURN", format = Luau.FORMAT_ABC, aux = false },
    [23] = { name = "JUMP", format = Luau.FORMAT_AD, aux = false },
    [24] = { name = "JUMPBACK", format = Luau.FORMAT_AD, aux = false },
    [25] = { name = "JUMPIF", format = Luau.FORMAT_AD, aux = false },
    [26] = { name = "JUMPIFNOT", format = Luau.FORMAT_AD, aux = false },
    [27] = { name = "JUMPIFEQ", format = Luau.FORMAT_AD, aux = true },
    [28] = { name = "JUMPIFLE", format = Luau.FORMAT_AD, aux = true },
    [29] = { name = "JUMPIFLT", format = Luau.FORMAT_AD, aux = true },
    [30] = { name = "JUMPIFNOTEQ", format = Luau.FORMAT_AD, aux = true },
    [31] = { name = "JUMPIFNOTLE", format = Luau.FORMAT_AD, aux = true },
    [32] = { name = "JUMPIFNOTLT", format = Luau.FORMAT_AD, aux = true },
    [33] = { name = "ADD", format = Luau.FORMAT_ABC, aux = false },
    [34] = { name = "SUB", format = Luau.FORMAT_ABC, aux = false },
    [35] = { name = "MUL", format = Luau.FORMAT_ABC, aux = false },
    [36] = { name = "DIV", format = Luau.FORMAT_ABC, aux = false },
    [37] = { name = "MOD", format = Luau.FORMAT_ABC, aux = false },
    [38] = { name = "POW", format = Luau.FORMAT_ABC, aux = false },
    [39] = { name = "ADDK", format = Luau.FORMAT_ABC, aux = false },
    [40] = { name = "SUBK", format = Luau.FORMAT_ABC, aux = false },
    [41] = { name = "MULK", format = Luau.FORMAT_ABC, aux = false },
    [42] = { name = "DIVK", format = Luau.FORMAT_ABC, aux = false },
    [43] = { name = "MODK", format = Luau.FORMAT_ABC, aux = false },
    [44] = { name = "POWK", format = Luau.FORMAT_ABC, aux = false },
    [45] = { name = "AND", format = Luau.FORMAT_ABC, aux = false },
    [46] = { name = "OR", format = Luau.FORMAT_ABC, aux = false },
    [47] = { name = "ANDK", format = Luau.FORMAT_ABC, aux = false },
    [48] = { name = "ORK", format = Luau.FORMAT_ABC, aux = false },
    [49] = { name = "CONCAT", format = Luau.FORMAT_ABC, aux = false },
    [50] = { name = "NOT", format = Luau.FORMAT_AD, aux = false },
    [51] = { name = "MINUS", format = Luau.FORMAT_AD, aux = false },
    [52] = { name = "LENGTH", format = Luau.FORMAT_AD, aux = false },
    [53] = { name = "NEWTABLE", format = Luau.FORMAT_ABC, aux = true },
    [54] = { name = "DUPTABLE", format = Luau.FORMAT_AD, aux = false },
    [55] = { name = "SETLIST", format = Luau.FORMAT_ABC, aux = true },
    [56] = { name = "FORNPREP", format = Luau.FORMAT_AD, aux = false },
    [57] = { name = "FORNLOOP", format = Luau.FORMAT_AD, aux = false },
    [58] = { name = "FORGLOOP", format = Luau.FORMAT_AD, aux = true },
    [59] = { name = "FORGPREP_INEXT", format = Luau.FORMAT_AD, aux = false },
    [60] = { name = "FASTCALL3", format = Luau.FORMAT_ABC, aux = true },
    [61] = { name = "FORGPREP_NEXT", format = Luau.FORMAT_AD, aux = false },
    [62] = { name = "GETVARARGS", format = Luau.FORMAT_ABC, aux = false },
    [63] = { name = "DUPCLOSURE", format = Luau.FORMAT_AD, aux = false },
    [64] = { name = "BREAKPOINT", format = Luau.FORMAT_ABC, aux = false },
    [65] = { name = "FALLTHROUGH", format = Luau.FORMAT_ABC, aux = false },
    [66] = { name = "COVERAGE", format = Luau.FORMAT_E, aux = false },
    [67] = { name = "CAPTURE", format = Luau.FORMAT_AD, aux = false },
    [68] = { name = "SUBRK", format = Luau.FORMAT_ABC, aux = false },
    [69] = { name = "DIVRK", format = Luau.FORMAT_ABC, aux = false },
    [70] = { name = "FASTCALL", format = Luau.FORMAT_ABC, aux = false },
    [71] = { name = "FASTCALL1", format = Luau.FORMAT_ABC, aux = false },
    [72] = { name = "FASTCALL2", format = Luau.FORMAT_ABC, aux = true },
    [73] = { name = "FASTCALL2K", format = Luau.FORMAT_ABC, aux = true },
    [74] = { name = "FORGPREP", format = Luau.FORMAT_AD, aux = false },
    [75] = { name = "JUMPXEQKNIL", format = Luau.FORMAT_AD, aux = true },
    [76] = { name = "JUMPXEQKB", format = Luau.FORMAT_AD, aux = true },
    [77] = { name = "JUMPXEQKN", format = Luau.FORMAT_AD, aux = true },
    [78] = { name = "JUMPXEQKS", format = Luau.FORMAT_AD, aux = true },
    [79] = { name = "IDIV", format = Luau.FORMAT_ABC, aux = false },
    [80] = { name = "IDIVK", format = Luau.FORMAT_ABC, aux = false }
}

return Luau
