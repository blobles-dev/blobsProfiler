blobsProfiler.RegisterModule("Network", {
    Icon = "icon16/drive_network.png",
    OrderPriority = 6,
    UpdateRealmData = function(luaState)
        if luaState == "Client" then    
            local netRecieversData = {}
            for recvName, recvFunc in pairs(net.Receivers) do
                recvName = tostring(recvName)

                local debugInfo = debug.getinfo(recvFunc)
                netRecieversData[recvName] = debugInfo
                netRecieversData[recvName].func = recvFunc
                
                netRecieversData[recvName].fakeVarType = "function"
            end

            blobsProfiler.Client.Network = netRecieversData
        else
            net.Start("blobsProfiler:requestData")
                net.WriteString("Network")
            net.SendToServer()
        end
    end,
    PrepServerData = function()
        local netRecieversData = {}
        for recvName, recvFunc in pairs(net.Receivers) do
            recvName = tostring(recvName)
            
            local debugInfo = debug.getinfo(recvFunc)
            netRecieversData[recvName] = debugInfo
            netRecieversData[recvName].func = tostring(recvFunc)
            
            netRecieversData[recvName].fakeVarType = "function"
        end

        return netRecieversData
    end,
    PreloadClient = true,
    PreloadServer = false,
    BuildPanel = function(luaState, parentPanel)
		blobsProfiler.buildDTree(luaState, parentPanel, "Network")
    end,
    RefreshButton = "Re-scan"
})