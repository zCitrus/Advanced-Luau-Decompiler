--[[
    Static AST Analyzer & API Interface Stub Generator
    Repository: https://github.com/zCitrus/Advanced-Luau-Decompiler
    Purpose: Statically extracts remote calls and function signatures 
             from decompiled Lua source and generates structured API stubs.
--]]

local Analyzer = {}

-- Utility: Trims whitespace from strings
local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Utility: Sanitizes identifier names
local function sanitizeIdentifier(name)
    local clean = name:gsub("[^%w_]", "_")
    if clean:match("^%d") then
        clean = "_" .. clean
    end
    return clean
end

--[[
    Analyzes decompiled source code to extract:
    1. RemoteEvent invocations (:FireServer)
    2. RemoteFunction invocations (:InvokeServer)
    3. Exported functions and global calls
--]]
function Analyzer.analyzeSource(decompiledCode)
    local results = {
        remoteEvents = {},
        remoteFunctions = {},
        functions = {}
    }

    if type(decompiledCode) ~= "string" or #decompiledCode == 0 then
        return results
    end

    local seenRemotes = {}

    -- 1. Scan for RemoteEvent :FireServer calls
    for line in decompiledCode:gmatch("[^\r\n]+") do
        local caller, args = line:match("([%w_%.%:%[%]\"']+):[Ff]ire[Ss]erver%((.-)%)")
        if caller and not seenRemotes[caller .. ":FireServer"] then
            seenRemotes[caller .. ":FireServer"] = true
            table.insert(results.remoteEvents, {
                caller = trim(caller),
                args = trim(args)
            })
        end

        -- 2. Scan for RemoteFunction :InvokeServer calls
        local invoker, invArgs = line:match("([%w_%.%:%[%]\"']+):[Ii]nvoke[Ss]erver%((.-)%)")
        if invoker and not seenRemotes[invoker .. ":InvokeServer"] then
            seenRemotes[invoker .. ":InvokeServer"] = true
            table.insert(results.remoteFunctions, {
                caller = trim(invoker),
                args = trim(invArgs)
            })
        end

        -- 3. Scan for standalone declared functions
        local fnName, fnParams = line:match("local%s+function%s+([%w_]+)%((.-)%)")
        if fnName then
            table.insert(results.functions, {
                name = fnName,
                params = trim(fnParams)
            })
        end
    end

    return results
end

--[[
    Generates a structured, executable API wrapper script from analyzed patterns.
--]]
function Analyzer.generateInterfaceScript(decompiledCode, scriptName)
    local analysis = Analyzer.analyzeSource(decompiledCode)
    local name = scriptName or "TargetScript"
    local output = {}

    table.insert(output, "-- ==============================================================================")
    table.insert(output, string.format("-- Auto-Generated API Interface Wrapper for [%s]", name))
    table.insert(output, "-- Generated via Advanced Luau Decompiler & Analyzer")
    table.insert(output, "-- ==============================================================================\n")

    table.insert(output, "local ReplicatedStorage = game:GetService(\"ReplicatedStorage\")")
    table.insert(output, "local Players = game:GetService(\"Players\")")
    table.insert(output, "local LocalPlayer = Players.LocalPlayer\n")

    table.insert(output, "local API = {}\n")

    -- Generate RemoteEvent wrappers
    if #analysis.remoteEvents > 0 then
        table.insert(output, "-- --- [ RemoteEvent Interface Wrappers ] --- --")
        for i, event in ipairs(analysis.remoteEvents) do
            local cleanName = sanitizeIdentifier(event.caller:match("([%w_]+)$") or ("Event_" .. i))
            local paramList = (event.args ~= "") and event.args or "..."

            table.insert(output, string.format("function API.fire_%s(%s)", cleanName, paramList))
            table.insert(output, string.format("    local remote = %s", event.caller))
            table.insert(output, "    if remote and remote:IsA(\"RemoteEvent\") then")
            table.insert(output, string.format("        remote:FireServer(%s)", paramList))
            table.insert(output, "    else")
            table.insert(output, string.format("        warn(\"[-] RemoteEvent not found: %s\")", event.caller))
            table.insert(output, "    end")
            table.insert(output, "end\n")
        end
    end

    -- Generate RemoteFunction wrappers
    if #analysis.remoteFunctions > 0 then
        table.insert(output, "-- --- [ RemoteFunction Interface Wrappers ] --- --")
        for i, func in ipairs(analysis.remoteFunctions) do
            local cleanName = sanitizeIdentifier(func.caller:match("([%w_]+)$") or ("Function_" .. i))
            local paramList = (func.args ~= "") and func.args or "..."

            table.insert(output, string.format("function API.invoke_%s(%s)", cleanName, paramList))
            table.insert(output, string.format("    local remote = %s", func.caller))
            table.insert(output, "    if remote and remote:IsA(\"RemoteFunction\") then")
            table.insert(output, string.format("        return remote:InvokeServer(%s)", paramList))
            table.insert(output, "    else")
            table.insert(output, string.format("        warn(\"[-] RemoteFunction not found: %s\")", func.caller))
            table.insert(output, "    end")
            table.insert(output, "end\n")
        end
    end

    -- If no network endpoints were detected
    if #analysis.remoteEvents == 0 and #analysis.remoteFunctions == 0 then
        table.insert(output, "-- [*] No direct RemoteEvent/RemoteFunction calls were detected in this script.")
        table.insert(output, "-- Static Function Stubs Extracted:")
        for _, fn in ipairs(analysis.functions) do
            table.insert(output, string.format("-- function %s(%s)", fn.name, fn.params))
        end
        table.insert(output, "")
    end

    table.insert(output, "return API")

    return table.concat(output, "\n")
end

return Analyzer
