--[[
    Advanced Luau Dynamic Instrumentation & Hook Engine
    Repository: https://github.com/zCitrus/Advanced-Luau-Decompiler
    Output: Ready-to-execute function interception and runtime modification harness.
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
        functions = {},
        methods = {},
        stateVariables = {},
        remotes = {}
    }

    if type(code) ~= "string" or #code == 0 then
        return results
    end

    local seenFns = {}
    local seenVars = {}
    local seenRemotes = {}

    for line in code:gmatch("[^\r\n]+") do
        local trimmed = trim(line)

        -- 1. Table Methods (e.g., function v1.createTaser(p8, p9) or v1["set"] = function(p3))
        local tObj, tMethod, tParams = trimmed:match("function%s+([%w_]+)[%.%:]([%w_]+)%((.-)%)")
        if not tObj then
            tObj, tMethod, tParams = trimmed:match("([%w_]+)%[[\"']([%w_]+)[\"']%]%s*=%s*function%((.-)%)")
        end
        if tObj and tMethod and not seenFns[tObj .. "." .. tMethod] then
            seenFns[tObj .. "." .. tMethod] = true
            table.insert(results.methods, {
                object = tObj,
                name = tMethod,
                params = trim(tParams)
            })
        end

        -- 2. Local Functions (e.g., local function handleTazed())
        local lFnName, lFnParams = trimmed:match("local%s+function%s+([%w_]+)%((.-)%)")
        if lFnName and not seenFns[lFnName] then
            seenFns[lFnName] = true
            table.insert(results.functions, {
                name = lFnName,
                params = trim(lFnParams)
            })
        end

        -- 3. Remotes (:FireServer, :InvokeServer)
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

        -- 4. State Variables & Return Dictionaries
        for key, val in trimmed:gmatch('"%s*([%w_]+)%s*"%s*]=%s*([-%w_%.%"]+)') do
            if not seenVars[key] then
                seenVars[key] = true
                table.insert(results.stateVariables, { name = key, value = val })
            end
        end
    end

    return results
end

function Analyzer.generateInterfaceScript(code, scriptName, scriptPath, scriptFullName, scriptClass)
    local data = Analyzer.deepAnalyze(code)
    local name = scriptName or "TargetScript"
    local path = scriptPath or ("game:GetService(\"ReplicatedStorage\"):WaitForChild(\"" .. name .. "\")")
    local fullName = scriptFullName or name
    local className = scriptClass or "LuaSourceContainer"

    local output = {}

    table.insert(output, "--!strict")
    table.insert(output, "-- ==============================================================================")
    table.insert(output, string.format("-- ⚡ Dynamic Function Instrumentation & Modification Suite: %s", name))
    table.insert(output, string.format("-- 📍 Executable Path : %s", path))
    table.insert(output, string.format("-- 🌳 DataModel Path  : %s", fullName))
    table.insert(output, string.format("-- 🏷️ Class Type      : %s", className))
    table.insert(output, "-- ==============================================================================\n")

    table.insert(output, "local Players = game:GetService(\"Players\")")
    table.insert(output, "local ReplicatedStorage = game:GetService(\"ReplicatedStorage\")")
    table.insert(output, "local LocalPlayer = Players.LocalPlayer\n")

    table.insert(output, "-- [ 1. Target Instance & Environment Reference ]")
    table.insert(output, string.format("local TargetInstance = %s", path))
    table.insert(output, "local TargetModule = (TargetInstance:IsA(\"ModuleScript\") and require(TargetInstance)) or {}\n")

    -- 2. Configuration & Parameter Matrix
    table.insert(output, "-- [ 2. Global Modification Matrix & Toggles ]")
    table.insert(output, "local ModSuite = {")
    table.insert(output, "    LoggingEnabled = true,   -- Logs function calls, args, and return values")
    table.insert(output, "    OverridesEnabled = true, -- Enables active parameter & return hooks")
    table.insert(output, "    Parameters = {")
    if #data.stateVariables > 0 then
        for _, var in ipairs(data.stateVariables) do
            table.insert(output, string.format("        %s = %s,", var.name, var.value))
        end
    else
        table.insert(output, "        Multiplier = 1.0,")
        table.insert(output, "        BypassCooldowns = true,")
    end
    table.insert(output, "    },")
    table.insert(output, "    CallHistory = {},")
    table.insert(output, "}\n")

    -- 3. Dynamic Method & Function Hook Registries
    table.insert(output, "-- [ 3. Dynamic Function Hook Handlers ]")
    table.insert(output, "local HookRegistry = {}\n")

    -- Generate Table Method Interceptors
    if #data.methods > 0 then
        for _, m in ipairs(data.methods) do
            local cleanName = sanitizeIdentifier(m.name)
            local params = (m.params ~= "") and m.params or "..."

            table.insert(output, string.format("-- Interceptor for Method: %s.%s(%s)", m.object, m.name, params))
            table.insert(output, string.format("HookRegistry[\"%s\"] = {", cleanName))
            table.insert(output, string.format("    Original = TargetModule[\"%s\"],", m.name))
            table.insert(output, "    Active = true,")
            table.insert(output, "    PreHook = function(...)")
            table.insert(output, "        local args = { ... }")
            table.insert(output, string.format("        if ModSuite.LoggingEnabled then"))
            table.insert(output, string.format("            print(string.format(\"[Hook: %s] Pre-Call | Args: %%s\", table.concat(args, \", \")))", cleanName))
            table.insert(output, "        end")
            table.insert(output, "        -- Modify 'args' before passing to original function if needed:")
            table.insert(output, "        return unpack(args)")
            table.insert(output, "    end,")
            table.insert(output, "    PostHook = function(returns, ...)")
            table.insert(output, "        -- Modify or override return values before caller receives them:")
            table.insert(output, "        return returns")
            table.insert(output, "    end,")
            table.insert(output, "}\n")
        end
    end

    -- Generate Local Function Stubs
    if #data.functions > 0 then
        for _, fn in ipairs(data.functions) do
            local cleanName = sanitizeIdentifier(fn.name)
            local params = (fn.params ~= "") and fn.params or "..."

            table.insert(output, string.format("-- Interceptor for Local Function: %s(%s)", fn.name, params))
            table.insert(output, string.format("HookRegistry[\"%s\"] = {", cleanName))
            table.insert(output, "    Active = true,")
            table.insert(output, string.format("    CustomExecution = function(%s)", params))
            table.insert(output, "        if ModSuite.LoggingEnabled then")
            table.insert(output, string.format("            print(\"[Hook: %s] Intercepted execution\")", cleanName))
            table.insert(output, "        end")
            table.insert(output, "        -- Custom replacement logic here:")
            table.insert(output, "    end,")
            table.insert(output, "}\n")
        end
    end

    -- 4. Hook Application & Restoration Manager
    table.insert(output, "-- [ 4. Hook Lifecycle Controller ]")
    table.insert(output, "function ModSuite.applyHooks()")
    table.insert(output, "    if not TargetModule or type(TargetModule) ~= \"table\" then")
    table.insert(output, "        warn(\"[-] Target is not a ModuleScript table; applying local runtime wrappers.\")")
    table.insert(output, "        return")
    table.insert(output, "    end\n")
    table.insert(output, "    for name, hookData in pairs(HookRegistry) do")
    table.insert(output, "        if TargetModule[name] and hookData.Original then")
    table.insert(output, "            TargetModule[name] = function(...)")
    table.insert(output, "                if not hookData.Active or not ModSuite.OverridesEnabled then")
    table.insert(output, "                    return hookData.Original(...)")
    table.insert(output, "                end")
    table.insert(output, "                -- 1. Execute Pre-Hook (Argument Manipulation)")
    table.insert(output, "                local modifiedArgs = { hookData.PreHook(...) }")
    table.insert(output, "                -- 2. Execute Original Logic")
    table.insert(output, "                local originalResults = { hookData.Original(unpack(modifiedArgs)) }")
    table.insert(output, "                -- 3. Execute Post-Hook (Return Value Manipulation)")
    table.insert(output, "                return hookData.PostHook(unpack(originalResults))")
    table.insert(output, "            end")
    table.insert(output, "            print(string.format(\"[+] Hook active: %s\", name))")
    table.insert(output, "        end")
    table.insert(output, "    end")
    table.insert(output, "end\n")

    table.insert(output, "function ModSuite.restoreHooks()")
    table.insert(output, "    if type(TargetModule) ~= \"table\" then return end")
    table.insert(output, "    for name, hookData in pairs(HookRegistry) do")
    table.insert(output, "        if hookData.Original then")
    table.insert(output, "            TargetModule[name] = hookData.Original")
    table.insert(output, "        end")
    table.insert(output, "    end")
    table.insert(output, "    print(\"[+] All hooks successfully restored to original state.\")")
    table.insert(output, "end\n")

    -- 5. Network Remote Dispatchers
    if #data.remotes > 0 then
        table.insert(output, "-- [ 5. Direct Network Dispatchers ]")
        table.insert(output, "local Network = {}\n")
        for i, rem in ipairs(data.remotes) do
            local cleanName = sanitizeIdentifier(rem.caller:match("([%w_]+)$") or ("Remote_" .. i))
            local params = (rem.args ~= "") and rem.args or "..."

            if rem.isEvent then
                table.insert(output, string.format("function Network.fire_%s(%s)", cleanName, params))
                table.insert(output, string.format("    local remote = %s", rem.caller))
                table.insert(output, "    if remote and remote:IsA(\"RemoteEvent\") then")
                table.insert(output, string.format("        remote:FireServer(%s)", params))
                table.insert(output, "    end")
                table.insert(output, "end\n")
            else
                table.insert(output, string.format("function Network.invoke_%s(%s)", cleanName, params))
                table.insert(output, string.format("    local remote = %s", rem.caller))
                table.insert(output, "    if remote and remote:IsA(\"RemoteFunction\") then")
                table.insert(output, string.format("        return remote:InvokeServer(%s)", params))
                table.insert(output, "    end")
                table.insert(output, "end\n")
            end
        end
        table.insert(output, "ModSuite.Network = Network\n")
    end

    table.insert(output, "-- Auto-apply hooks on script execution")
    table.insert(output, "ModSuite.applyHooks()\n")
    table.insert(output, "return ModSuite")

    return table.concat(output, "\n")
end

return Analyzer
