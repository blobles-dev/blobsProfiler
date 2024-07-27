blobsProfiler.original_timerCreate = blobsProfiler.original_timerCreate or timer.Create

local createdTimers = createdTimers or {}

function timer.Create(identifier, delay, reps, func)
	createdTimers[identifier] = {
		["Delay: "..delay] = delay, -- kill me now
		["Repititions: "..reps] = reps or 0, -- kill me now
		["Function: "..tostring(func)] = tostring(func) -- kill me now
	}

	return blobsProfiler.original_timerCreate(identifier, delay, reps, func)
end

blobsProfiler.RegisterModule("Timers", {
    Icon = "icon16/clock.png",
    OrderPriority = 6,
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
    RefreshButton = "Refresh"
})