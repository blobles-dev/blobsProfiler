blobsProfiler.RegisterModule("Profiling", {
    Icon = "icon16/hourglass.png",
    OrderPriority = 1
})

local function profileLog(luaState, event)
    local info = debug.getinfo(3, "f")
    if not info then return end -- ???

    local funcId = tostring(info.func)
    if blobsProfiler[luaState].Profile.Raw[funcId] then
        if event == "call" then
            blobsProfiler[luaState].Profile.Called[funcId] = SysTime()
        elseif event == "return" then
            if blobsProfiler[luaState].Profile.Called[funcId] then
                local timeToRun = SysTime() - blobsProfiler[luaState].Profile.Called[funcId]
                blobsProfiler[luaState].Profile.Called[funcId] = nil
                table.insert(blobsProfiler[luaState].Profile.Results[funcId], timeToRun)
            end
        end
    end
end

if not blobsProfiler.Modules["Profiling"].ProfilingStatus then
    blobsProfiler.Modules["Profiling"].ProfilingStatus = {}
    blobsProfiler.Modules["Profiling"].ProfilingStatus["Client"] = false
    blobsProfiler.Modules["Profiling"].ProfilingStatus["Server"] = false
end


blobsProfiler.RegisterSubModule("Profiling", "Targets", {
    Icon = "icon16/book_addresses.png",
    OrderPriority = 1,
    OnOpen = function(luaState, parentPanel)
        local profilerTable = blobsProfiler[luaState].Profile or {}
        local profilerData = table.Copy(profilerTable)
        profilerData.Raw = nil -- we dont need to display these
        profilerData.Called = nil
        profilerData.Results = nil

        blobsProfiler.buildDTree(luaState, parentPanel, "Profiling.Targets", profilerData)

        if parentPanel.startProfilingButton and IsValid(parentPanel.startProfilingButton) then
            parentPanel.startProfilingButton:Remove()
            parentPanel.startProfilingButton = nil
        end
        if parentPanel.stopProfilingButton and IsValid(parentPanel.stopProfilingButton) then
            parentPanel.stopProfilingButton:Remove()
            parentPanel.stopProfilingButton = nil
        end

        parentPanel.startProfilingButton = vgui.Create("DButton", parentPanel)
        parentPanel.stopProfilingButton = vgui.Create("DButton", parentPanel)

        parentPanel.startProfilingButton:SetText("Start profiling")
        parentPanel.stopProfilingButton:SetText("Stop profiling")

        parentPanel.stopProfilingButton:Dock(BOTTOM)
        parentPanel.startProfilingButton:Dock(BOTTOM)

        parentPanel.startProfilingButton:SetEnabled(not blobsProfiler.Modules["Profiling"].ProfilingStatus[luaState])
        parentPanel.stopProfilingButton:SetEnabled(blobsProfiler.Modules["Profiling"].ProfilingStatus[luaState])

        parentPanel.startProfilingButton.DoClick = function()
            if not blobsProfiler.CanAccess(LocalPlayer(), "Profiling_"..luaState) then return end
            if luaState == "Client" then
                blobsProfiler.Modules["Profiling"].ProfilingStatus[luaState] = true
                debug.sethook(function(e) profileLog("Client", e) end, "cr")

                parentPanel.startProfilingButton:SetEnabled(not blobsProfiler.Modules["Profiling"].ProfilingStatus[luaState])
                parentPanel.stopProfilingButton:SetEnabled(blobsProfiler.Modules["Profiling"].ProfilingStatus[luaState])
            elseif luaState == "Server" then
                
            end
        end

        parentPanel.stopProfilingButton.DoClick = function()
            if not blobsProfiler.CanAccess(LocalPlayer(), "Profiling_"..luaState) then return end
            if luaState == "Client" then
                blobsProfiler.Modules["Profiling"].ProfilingStatus[luaState] = false
                debug.sethook()

                parentPanel.startProfilingButton:SetEnabled(not blobsProfiler.Modules["Profiling"].ProfilingStatus[luaState])
                parentPanel.stopProfilingButton:SetEnabled(blobsProfiler.Modules["Profiling"].ProfilingStatus[luaState])
            elseif luaState == "Server" then
                
            end
        end
    end
})

blobsProfiler.RegisterSubModule("Profiling", "Results", {
    Icon = "icon16/chart_bar.png",
    OrderPriority = 2
})