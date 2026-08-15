# Advanced Luau Decompiler (Patched & Up to Date)

An updated, pure-Lua Luau bytecode deserializer and decompiler engine supporting modern Luau bytecode (v3 to v6).

## Features
- Full support for Luau Bytecode v3 through v6.
- Updated opcode table matching canonical `Bytecode.h`.
- Supports Type Tables, Vector constants, and multi-word `AUX` instructions.
- Compatible with modern Roblox executors and standalone Luau VMs.

## Quick Usage (In-Game / Executor)

```lua
local Decompiler = loadstring(game:HttpGet("https://raw.githubusercontent.com/zCitrus/Advanced-Luau-Decompiler/main/init.lua"))()

local scriptBytecode = getscriptbytecode(workspace.SampleScript)
local source = Decompiler.decompile(scriptBytecode)

print(source)
