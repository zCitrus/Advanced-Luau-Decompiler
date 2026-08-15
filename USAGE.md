# 📖 How to Use

This guide explains how to load and use the Advanced Luau Decompiler in your environment.

---

## 1. Quick In-Game Decompilation

To decompile any client-accessible script (`LocalScript` or `ModuleScript`), run this in your executor:

```lua
local Decompiler = loadstring(game:HttpGet("https://raw.githubusercontent.com/zCitrus/Advanced-Luau-Decompiler/main/init.lua"))()

-- Select a LocalScript or ModuleScript
local targetScript = game.Players.LocalPlayer.PlayerScripts:FindFirstChildOfClass("LocalScript", true) 
    or game.ReplicatedStorage:FindFirstChildOfClass("ModuleScript", true)

if targetScript and getscriptbytecode then
    local bytecode = getscriptbytecode(targetScript)
    local decompiledCode = Decompiler.decompile(bytecode)
    
    print("--- Decompiled Code ---")
    print(decompiledCode)
    
    -- Optional: Copy to clipboard
    if setclipboard then
        setclipboard(decompiledCode)
    end
else
    warn("No valid script found or 'getscriptbytecode' is not supported.")
end
