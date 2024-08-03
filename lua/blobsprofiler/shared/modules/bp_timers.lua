blobsProfiler.original_timerCreate = blobsProfiler.original_timerCreate or timer.Create

local createdTimers = createdTimers or {}

function timer.Create(identifier, delay, reps, func)
    local debugInfo = debug.getinfo(func)

    createdTimers[identifier] = {
        ["Delay: "..delay] = delay,
        ["Repititions: "..reps] = reps or 0,
        [tostring(func)] = {
            fakeVarType = "function",
            func = CLIENT and func or tostring(func),
            lastlinedefined	= debugInfo.lastlinedefined,
            linedefined	= debugInfo.linedefined,
            short_src = debugInfo.short_src
        }
    }

	return blobsProfiler.original_timerCreate(identifier, delay, reps, func)
end

if SERVER then
    util.AddNetworkString("blobsProfiler:Timers_Control")
    net.Receive("blobsProfiler:Timers_Control", function(len,ply)
        if not blobsProfiler.CanAccess(ply, "Timers") then return end
        if not blobsProfiler.CanAccess(ply, "Timers_Control") then return end

        local timerName = net.ReadString()
        local Control = net.ReadUInt(2)

        if Control == 1 then
            timer.Pause(timerName)
        elseif Control == 2 then
            timer.UnPause(timerName)
        elseif Control == 3 then
            timer.Remove(timerName)
        elseif Control == 0 then
            createdTimers[timerName] = nil
        end

        blobsProfiler.SendModuleData("Timers", ply)
    end)
end

blobsProfiler.RegisterModule("Timers", {
    Icon = "icon16/clock.png",
    OrderPriority = 7,
    UpdateRealmData = function(luaState)
        if luaState == "Client" then
            -- why dont we just set it straight away ffs
            blobsProfiler.Client.Timers = createdTimers
        else
            net.Start("blobsProfiler:requestData")
                net.WriteString("Timers")
            net.SendToServer()
        end
    end,
    PrepServerData = function()
        for k,v in pairs(createdTimers) do
            local timerAlive = timer.Exists(k)
            v.timeLeft = timerAlive and timer.TimeLeft(k)
            v.isAlive = timerAlive
        end
        return createdTimers
    end,
    PreloadClient = true,
    PreloadServer = false,
    BuildPanel = function(luaState, parentPanel)
		blobsProfiler.buildDTree(luaState, parentPanel, "Timers")
    end,
    RefreshButton = "Refresh",
    RCFunctions = { -- TODO: fix 'timer.Exists' - this will obviously be false for server timers!
        ["table"] = { -- root node, timer identifier
            {
                name = "Print",
                func = function(ref, node)
                    print(ref.value)
                    print(node.GlobalPath)
                end,
                icon = "icon16/application_osx_terminal.png"
            },
            { -- Pause/Resume timer
                name = function(ref, node, luaState)
                    if luaState == "Client" and not timer.Exists(node.GlobalPath) then return end
                    if luaState == "Server" and not ref.value.isAlive then return end
                    local timeLeft = luaState == "Client" and timer.TimeLeft(node.GlobalPath) or ref.value.timeLeft
                    if timeLeft < 0 then
                        return "Resume"
                    else
                        return "Pause"
                    end
                end,
                func = function(ref, node, luaState)
                    if luaState == "Client" and not timer.Exists(node.GlobalPath) then return end
                    if luaState == "Server" and not ref.value.isAlive then return end
                    local timeLeft = luaState == "Client" and timer.TimeLeft(node.GlobalPath) or ref.value.timeLeft
                    if timeLeft < 0 then
                        if luaState == "Client" then
                            timer.UnPause(node.GlobalPath)
                        else
                            net.Start("blobsProfiler:Timers_Control")
                                net.WriteString(node.GlobalPath)
                                net.WriteUInt(2, 2)
                            net.SendToServer()
                        end
                        
                        node.Icon:SetImage("icon16/clock_stop.png")
                    else
                        if luaState == "Client" then
                            timer.Pause(node.GlobalPath)
                        else
                            net.Start("blobsProfiler:Timers_Control")
                                net.WriteString(node.GlobalPath)
                                net.WriteUInt(1, 2)
                            net.SendToServer()
                        end
                        node.Icon:SetImage("icon16/clock_play.png")
                    end
                end,
                onLoad = function(ref, node, luaState)
                    if luaState == "Client" and not timer.Exists(node.GlobalPath) then return end
                    if luaState == "Server" and not ref.value.isAlive then return end
                    local timeLeft = luaState == "Client" and timer.TimeLeft(node.GlobalPath) or ref.value.timeLeft
                    if timeLeft < 0 then
                        node.Icon:SetImage("icon16/clock_stop.png")
                    else
                        node.Icon:SetImage("icon16/clock_play.png")
                    end
                end,
                icon = function(ref, node, luaState)
                    if luaState == "Client" and not timer.Exists(node.GlobalPath) then return end
                    if luaState == "Server" and not ref.value.isAlive then return end
                    local timeLeft = luaState == "Client" and timer.TimeLeft(node.GlobalPath) or ref.value.timeLeft
                    if timeLeft < 0 then
                        return "icon16/clock_stop.png"
                    else
                        return "icon16/clock_play.png"
                    end
                end
            },
            { -- Delete timer
                name = function(ref, node, luaState)
                    if (luaState == "Client" and not timer.Exists(node.GlobalPath)) or (luaState == "Server" and not ref.value.isAlive) then
                        node.Label:SetTextColor(Color(255,0,0))
                        return
                    end
                    return "Delete"
                end,
                func = function(ref, node, luaState)
                    if luaState == "Client" then
                        timer.Remove(node.GlobalPath)
                    else
                        net.Start("blobsProfiler:Timers_Control")
                            net.WriteString(node.GlobalPath)
                            net.WriteUInt(3, 2)
                        net.SendToServer()
                    end
                    node.Label:SetTextColor(Color(255,0,0))
                    node.Icon:SetImage("icon16/clock_delete.png")
                end,
                onLoad = function(ref, node, luaState)
                    if (luaState == "Client" and not timer.Exists(node.GlobalPath)) or (luaState == "Server" and not ref.value.isAlive) then
                        node.Label:SetTextColor(Color(255,0,0))
                        node.Icon:SetImage("icon16/clock_delete.png")
                    end
                end,
                icon = "icon16/clock_delete.png"
            },
            { -- Remove timer reference
                name = function(ref, node, luaState)
                    if (luaState == "Client" and not timer.Exists(node.GlobalPath)) or (luaState == "Server" and not ref.value.isAlive) then
                        return "Remove reference"
                    end
                end,
                func = function(ref, node, luaState)
                    createdTimers[node.GlobalPath] = nil 

                    if luaState == "Server" then
                        net.Start("blobsProfiler:Timers_Control")
                            net.WriteString(node.GlobalPath)
                            net.WriteUInt(0, 2)
                        net.SendToServer()
                    end
                    
                    node:Remove()
                end,
                icon = "icon16/clock_red.png"
            }
        },
        ["function"] = {
            {
                name = "View source",
                func = function(ref, node, luaState)
                    if not string.EndsWith(ref.value.short_src, ".lua") then
                        Derma_Message("Invalid function source: ".. ref.value.short_src.."\nOnly functions defined in Lua can be read!", "Function view source", "OK")
                        return
                    end

                    net.Start("blobsProfiler:requestSource")
                        net.WriteString(ref.value.short_src)
                        net.WriteUInt(ref.value.linedefined, 16)
                        net.WriteUInt(ref.value.lastlinedefined, 16)
                    net.SendToServer()
                end,
                icon = "icon16/magnifier.png"
            },
            {
                name = "View properties",
                func = function(ref, node, luaState)
                    local propertiesData = {}
                    local propertiesTbl = table.Copy(ref.value)
                    propertiesTbl.fakeVarType = nil
                    propertiesData["debug.getinfo()"] = propertiesTbl

                    local popupView = blobsProfiler.viewPropertiesPopup("View Function: " .. ref.key, propertiesData)
                end,
                icon = "icon16/magnifier.png"
            }
        }
    }
})