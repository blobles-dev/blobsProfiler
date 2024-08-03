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
                name = function(ref, node)
                    if not timer.Exists(node.GlobalPath) then return end
                    local timeLeft = timer.TimeLeft(node.GlobalPath)
                    if timeLeft < 0 then
                        return "Resume"
                    else
                        return "Pause"
                    end
                end,
                func = function(ref, node)
                    if not timer.Exists(node.GlobalPath) then return end
                    local timeLeft = timer.TimeLeft(node.GlobalPath)
                    if timeLeft < 0 then
                        timer.UnPause(node.GlobalPath)
                        node.Icon:SetImage("icon16/clock_stop.png")
                    else
                        timer.Pause(node.GlobalPath)
                        node.Icon:SetImage("icon16/clock_play.png")
                    end
                end,
                onLoad = function(ref, node)
                    if not timer.Exists(node.GlobalPath) then return end
                    local timeLeft = timer.TimeLeft(node.GlobalPath)
                    if timeLeft < 0 then
                        node.Icon:SetImage("icon16/clock_stop.png")
                    else
                        node.Icon:SetImage("icon16/clock_play.png")
                    end
                end,
                icon = function(ref, node)
                    if not timer.Exists(node.GlobalPath) then return end
                    local timeLeft = timer.TimeLeft(node.GlobalPath)
                    if timeLeft < 0 then
                        return "icon16/clock_stop.png"
                    else
                        return "icon16/clock_play.png"
                    end
                end
            },
            { -- Delete timer
                name = function(ref, node)
                    if not timer.Exists(node.GlobalPath) then node.Label:SetTextColor(Color(255,0,0)) return end
                    return "Delete"
                end,
                func = function(ref, node)
                    timer.Remove(node.GlobalPath)
                    node.Label:SetTextColor(Color(255,0,0))
                    node.Icon:SetImage("icon16/clock_delete.png")
                end,
                onLoad = function(ref, node)
                    if not timer.Exists(node.GlobalPath) then
                        node.Label:SetTextColor(Color(255,0,0))
                        node.Icon:SetImage("icon16/clock_delete.png")
                    end
                end,
                icon = "icon16/clock_delete.png"
            },
            { -- Remove timer reference
                name = function(ref, node)
                    if not timer.Exists(node.GlobalPath) then return "Remove reference" end
                end,
                func = function(ref, node)
                    blobsProfiler.createdTimers[node.GlobalPath] = nil 
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