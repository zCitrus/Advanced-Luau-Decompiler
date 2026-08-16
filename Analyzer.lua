--[[
    Advanced Luau Semantic Analyzer & Hook Harness Generator (Path-Aware)
    Repository: https://github.com/zCitrus/Advanced-Luau-Decompiler
--]]

local Analyzer = {}

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function sanitizeIdentifier(name)
    local clean = name:gsub("[^%w_]", "_")
    if clean:match("^%d") then
        clean = "_" .. clean
    end
    return clean
end

function Analyzer.deepAnalyze(code)
    local results = {
        remotes = {},
        functions = {},
        stateVariables = {},
        configTables = {},
        mathCalculations = {}
    }

    if type(code) ~= "string" or #code == 0 then
        return results
    end

    local seenRemotes = {}
    local seenVars = {}

    for line in code:gmatch("[^\r\n]+") do
        local trimmed = trim(line)

        -- 1. Detect Remote Calls
        local rCaller, rMethod, rArgs = trimmed:match("([%w_%.%:%[%]\"']+):([Ff]ire[Ss]erver|[Ii]nvoke[Ss]erver)%((.-)%)")
        if rCaller and not seenRemotes[rCaller .. ":" .. rMethod] then
            seenRemotes[rCaller .. ":" .. rMethod] = true
            table.insert(results.remotes, {
                caller = rCaller,
                method = rMethod,
                args = trim(rArgs),
                isEvent = (rMethod:lower() == "fireserver")
            })
        end

        -- 2. Detect Function Declarations
        local fnName, fnParams = trimmed:match("local%s+function%s+([%w_]+)%((.-)%)")
        if not fnName then
            fnName, fnParams = trimmed:match("function%s+([%w_%.%:]+)%((.-)%)")
        end
        if fnName then
            table.insert(results.functions, {
                name = fnName,
                params = trim(fnParams)
            })
        end

        -- 3. Detect Mathematical Calculations
        local varName, expr = trimmed:match("([%w_%.%[%]]+)%s*=%s*(%b()|[-%w_%.%s%*%/%%%+%-]+)")
        if varName and expr and not trimmed:find("function") and not trimmed:find("==") then
            if expr:find("[%+%-%*%/%%]") and not seenVars[varName] then
                seenVars[varName] = true
                table.insert(results.mathCalculations, {
                    target = varName,
                    expression = trim(expr)
                })
            end
        end

        -- 4. Detect State Variables
        local sVar, sVal = trimmed:match("local%s+([%w_]+)%s*=%s*([%d%.]+)")
        if not sVar then
            sVar, sVal = trimmed:match("local%s+([%w_]+)%s*=%s*(\"[^\"]*\")")
        end
        if sVar and sVal and not seenVars[sVar] then
            seenVars[sVar] = true
            table.insert(results.stateVariables, {
                name = sVar,
                value = sVal
            })
        end

        -- 5. Detect Tables
        local tName = trimmed:match("local%s+([%w_]+)%s*=%s*{}")
        if tName then
            table.insert(results.configTables, tName)
        end
    end

    return results
end

--[[
    Generates a structured Harness with exact DataModel path resolution.
--]]
function Analyzer.generateInterfaceScript(code, scriptName, scriptPath, scriptFullName, scriptClass)
    local data = Analyzer.deepAnalyze(code)
    local name = scriptName or "TargetScript"
    local path = scriptPath or ("game:GetService(\"ReplicatedStorage\"):WaitForChild(\"" .. name .. "\")")
    local fullName = scriptFullName or name
    local className = scriptClass or "LuaSourceContainer"

    local output = {}

    table.insert(output, "-- ==============================================================================")
    table.insert(output, string.format("-- ⚡ AI-Ready Control & Override Harness for: %s", name))
    table.insert(output, string.format("-- 📍 Executable Lua Path : %s", path))
    table.insert(output, string.format("-- 🌳 Full DataModel Path: %s", fullName))
    table.insert(output, string.format("-- 🏷️ Class Type        : %s", className))
    table.insert(output, "-- ==============================================================================\n")

    table.insert(output, "local Players = game:GetService(\"Players\")")
    table.insert(output, "local ReplicatedStorage = game:GetService(\"ReplicatedStorage\")")
    table.insert(output, "local LocalPlayer = Players.LocalPlayer\n")

    table.insert(output, string.format("-- Reference to the exact target script instance:"))
    table.insert(output, string.format("local TargetScriptInstance = %s\n", path))

    -- 1. Configuration & Variable Modifiers
    table.insert(output, "-- [ 1. Extracted State & Configuration Overrides ]")
    table.insert(output, "local HarnessConfig = {")
    if #data.stateVariables > 0 then
        for _, var in ipairs(data.stateVariables) do
            table.insert(output, string.format("    %s = %s,", var.name, var.value))
        end
    else
        table.insert(output, "    Multiplier = 1.0,")
        table.insert(output, "    Enabled = true,")
    end
    table.insert(output, "}\n")

    -- 2. Math Handlers
    if #data.mathCalculations > 0 then
        table.insert(output, "-- [ 2. Mathematical Logic & Calculators ]")
        for i, mathOp in ipairs(data.mathCalculations) do
            local cleanFn = "calculate_" .. sanitizeIdentifier(mathOp.target) .. "_" .. i
            table.insert(output, string.format("local function %s(customFactor)", cleanFn))
            table.insert(output, string.format("    -- Original formula: %s", mathOp.expression))
            table.insert(output, string.format("    local baseResult = %s", mathOp.expression))
            table.insert(output, "    return baseResult * (customFactor or HarnessConfig.Multiplier or 1.0)")
            table.insert(output, "end\n")
        end
    end

    -- 3. Function Hooks
    table.insert(output, "-- [ 3. Function Interception & Hooks ]")
    table.insert(output, "local Hooks = {}\n")

    if #data.functions > 0 then
        for _, fn in ipairs(data.functions) do
            local cleanName = sanitizeIdentifier(fn.name)
            local params = (fn.params ~= "") and fn.params or "..."

            table.insert(output, string.format("function Hooks.hook_%s(originalFunction)", cleanName))
            table.insert(output, string.format("    return function(%s)", params))
            table.insert(output, string.format("        print(\"[Hook] %s called with:\", %s)", cleanName, params))
            table.insert(output, string.format("        if originalFunction then"))
            table.insert(output, string.format("            return originalFunction(%s)", params))
            table.insert(output, "        end")
            table.insert(output, "    end")
            table.insert(output, "end\n")
        end
    end

    -- 4. Remote Event & Function Wrappers
    if #data.remotes > 0 then
        table.insert(output, "-- [ 4. Network Remote Dispatchers ]")
        table.insert(output, "local Network = {}\n")

        for i, rem in ipairs(data.remotes) do
            local cleanName = sanitizeIdentifier(rem.caller:match("([%w_]+)$") or ("Remote_" .. i))
            local params = (rem.args ~= "") and rem.args or "..."

            if rem.isEvent then
                table.insert(output, string.format("function Network.fire_%s(%s)", cleanName, params))
                table.insert(output, string.format("    local remote = %s", rem.caller))
                table.insert(output, "    if remote and remote:IsA(\"RemoteEvent\") then")
                table.insert(output, string.format("        remote:FireServer(%s)", params))
                table.insert(output, "    else")
                table.insert(output, string.format("        warn(\"[-] RemoteEvent not found: %s\")", rem.caller))
                table.insert(output, "    end")
                table.insert(output, "end\n")
            else
                table.insert(output, string.format("function Network.invoke_%s(%s)", cleanName, params))
                table.insert(output, string.format("    local remote = %s", rem.caller))
                table.insert(output, "    if remote and remote:IsA(\"RemoteFunction\") then")
                table.insert(output, string.format("        return remote:InvokeServer(%s)", params))
                table.insert(output, "    else")
                table.insert(output, string.format("        warn(\"[-] RemoteFunction not found: %s\")", rem.caller))
                table.insert(output, "    end")
                table.insert(output, "end\n")
            end
        end
    end

    -- 5. Export
    table.insert(output, "-- [ 5. Export Controller ]")
    table.insert(output, "return {")
    table.insert(output, "    Target = TargetScriptInstance,")
    table.insert(output, "    Config = HarnessConfig,")
    table.insert(output, "    Hooks = Hooks,")
    if #data.remotes > 0 then
        table.insert(output, "    Network = Network,")
    end
    table.insert(output, "}")

    return table.concat(output, "\n")
end

return Analyzer
