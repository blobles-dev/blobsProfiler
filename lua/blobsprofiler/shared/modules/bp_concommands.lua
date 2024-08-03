blobsProfiler.RegisterModule("ConCommands", {
    Icon = "icon16/application_xp_terminal.png",
    OrderPriority = 4,
    UpdateRealmData = function(luaState)
        if luaState == "Client" then
            local concmdTbl = concommand.GetTable()
            local concommandsData = {}

            for ccName, ccFunc in pairs(concmdTbl) do
                ccName = tostring(ccName)

                local debugInfo = debug.getinfo(ccFunc)
                concommandsData[ccName] = debugInfo
                concommandsData[ccName].func = ccFunc
                
                concommandsData[ccName].fakeVarType = "function"
            end

            blobsProfiler.Client.ConCommands = concommandsData
        else
            net.Start("blobsProfiler:requestData")
                net.WriteString("ConCommands")
            net.SendToServer()
        end
    end,
    PrepServerData = function()
        local concmdTbl = concommand.GetTable()
        local concommandsData = {}

        for ccName, ccFunc in pairs(concmdTbl) do
            ccName = tostring(ccName)

            local debugInfo = debug.getinfo(ccFunc)
            concommandsData[ccName] = debugInfo
            concommandsData[ccName].func = tostring(ccFunc)
            
            concommandsData[ccName].fakeVarType = "function"
        end

        return concommandsData
    end,
    PreloadClient = true,
    PreloadServer = false,
    BuildPanel = function(luaState, parentPanel)
		blobsProfiler.buildDTree(luaState, parentPanel, "ConCommands")
    end,
    RefreshButton = "Re-scan"
})