blobsProfiler.RegisterModule("Hooks", {
    Icon = "icon16/brick_add.png",
    OrderPriority = 3,
    UpdateRealmData = function(luaState)
        if luaState == "Client" then
            local hooksTable = {}
            for hookName, hookEvents in pairs(hook.GetTable()) do
                hooksTable[hookName] = hooksTable[hookName] or {}
    
                for eventName, eventFunc in pairs(hookEvents) do
                    local debugInfo = debug.getinfo(eventFunc)
                    hooksTable[hookName][eventName] = debugInfo
                    hooksTable[hookName][eventName].func = eventFunc

                    hooksTable[hookName][eventName].fakeVarType = "function"
                end
            end
    
            blobsProfiler.Client.Hooks = hooksTable
        else
            net.Start("blobsProfiler:requestData")
                net.WriteString("Hooks")
            net.SendToServer()
        end
    end,
    PrepServerData = function()
        local hooksTable = {}
        for hookName, hookEvents in pairs(hook.GetTable()) do
            hooksTable[hookName] = hooksTable[hookName] or {}

            for eventName, eventFunc in pairs(hookEvents) do
                local debugInfo = debug.getinfo(eventFunc)
                hooksTable[hookName][eventName] = debugInfo
                hooksTable[hookName][eventName].func = tostring(eventFunc)

                hooksTable[hookName][eventName].fakeVarType = "function"
            end
        end

        return hooksTable
    end,
    PreloadClient = true,
    PreloadServer = false,
    BuildPanel = function(luaState, parentPanel)
		blobsProfiler.buildDTree(luaState, parentPanel, "Hooks")
    end,
    RefreshButton = "Re-scan"
})