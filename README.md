# Advanced Luau Decompiler (v6 Patched)

An up-to-date, pure-Lua Luau bytecode deserializer and decompiler engine supporting modern Luau bytecode revisions (v3 through v6).

## Features
- **Modern Opcode Support:** Updated opcode table matching canonical `Bytecode.h` (includes `IDIV`, `FASTCALL3`, `JUMPXEQ`, and Vector types).
- **Fast & Pure Lua:** Uses `string.unpack` with binary fallbacks for maximum performance.
- **Standalone:** Zero external network dependencies once loaded.

## Usage

```lua
local Decompiler = loadstring(game:HttpGet("https://raw.githubusercontent.com/zCitrus/Advanced-Luau-Decompiler/main/init.lua"))()

-- Decompile any script's bytecode
local scriptBytecode = getscriptbytecode(workspace.SampleScript)
local source = Decompiler.decompile(scriptBytecode)

print(source)
