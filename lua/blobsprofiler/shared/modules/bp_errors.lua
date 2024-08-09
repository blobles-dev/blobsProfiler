blobsProfiler.RegisterModule("Errors", {
    Icon = "icon16/bug.png",
    OrderPriority = 9,
    UpdateRealmData = function(luaState)
        if luaState == "Client" then
            -- we dont need to set, it's automatically set by the OnLuaError hook
        else
            net.Start("blobsProfiler:requestData")
                net.WriteString("Errors")
            net.SendToServer()
        end
    end,
    PrepServerData = function()
        return blobsProfiler.Server and blobsProfiler.Server.Errors or {}
    end,
    PreloadClient = true,
    PreloadServer = false,
    BuildPanel = function(luaState, parentPanel)
		blobsProfiler.buildDTree(luaState, parentPanel, "Errors")
    end,
    OnOpen = function(luaState, parentPanel)
        if luaState == "Client" then
            blobsProfiler.buildDTree(luaState, parentPanel, "Errors")
        end
    end,
    RefreshButton = "Reload",
    FormatNodeName = function(luaState, nodeKey, nodeValue)
        if nodeKey == "Last Errored" or nodeKey == "First Errored" then
            return nodeKey .. ": ".. os.date("%c", nodeValue)
        elseif not istable(nodeValue) then
            return nodeKey .. ": ".. tostring(nodeValue)
        elseif istable(nodeValue) and nodeValue.Error then
            return nodeValue.Error
        elseif istable(nodeValue) and nodeValue.fakeVarType == "file" then
            return "[" .. nodeValue.Level .. "] " .. nodeValue.Source .. ":" ..nodeValue.Line
        end

        return nodeKey
    end,
    FormatNodeIcon = function(luaState, nodeKey, nodeValue)
        if nodeKey == "Last Errored" or nodeKey == "First Errored" then
            return "icon16/clock.png"
        elseif nodeKey == "Count" then
            return "icon16/chart_bar.png"
        elseif nodeKey == "Stacktrace" then
            return "icon16/script_error.png"
        elseif nodeKey == "Addon ID" then
            return "icon16/plugin_link.png"
        elseif istable(nodeValue) and nodeValue.Stacktrace and nodeValue.Count then
            return "icon16/bug_error.png"
        elseif istable(nodeValue) and nodeValue.fakeVarType == "file" then
            return "icon16/page_white_code.png"
        end
    end
})

local function capitalizeFirstLetter(str)
    return (str and str:sub(1, 1):upper() .. str:sub(2):lower()) or str -- are you shitting me
end

hook.Add("OnLuaError", "test", function( err, realm, stack, name, addon_id )
    local luaState = capitalizeFirstLetter(realm)

    name = name or "Unknown Origin"
    err = err or "Unknown Error" -- should this ever happen?

    local errorKey = util.CRC(err .. "\n" .. (stack and util.TableToJSON(stack) or "No Stack Trace"))

    blobsProfiler[luaState] = blobsProfiler[luaState] or {}
    blobsProfiler[luaState].Errors = blobsProfiler[luaState].Errors or {}
    blobsProfiler[luaState].Errors[name] = blobsProfiler[luaState].Errors[name] or {}

    if not blobsProfiler[luaState].Errors[name][errorKey] then
        local genStack
        for k, stackDetails in ipairs(stack) do
            genStack = genStack or {}

            local stackData = {}
            stackData.fakeVarType = "file"
            stackData.Level = k
            stackData.Func = tostring(stackDetails.Function)
            stackData.Source = stackDetails.File
            stackData.Line = stackDetails.Line

            table.insert(genStack, stackData)
        end

        blobsProfiler[luaState].Errors[name][errorKey] = {
            Error = err,
            Count = 1,
            Stacktrace = genStack,
            ["Addon ID"] = (tonumber(addon_id) ~= 0) and addon_id or nil,
            ["First Errored"] = os.time()
        }
    else
        blobsProfiler[luaState].Errors[name][errorKey].Count = blobsProfiler[luaState].Errors[name][errorKey].Count + 1
        blobsProfiler[luaState].Errors[name][errorKey]["Last Errored"] = os.time()
    end
end)