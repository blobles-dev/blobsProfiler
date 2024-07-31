blobsProfiler.RegisterModule("Profiling", {
    Icon = "icon16/hourglass.png",
    OrderPriority = 1
})

blobsProfiler.RegisterSubModule("Profiling", "Targets", {
    Icon = "icon16/book_addresses.png",
    OrderPriority = 1,
    OnOpen = function(luaState, parentPanel)
        print("on open func bp profiling", luaState, parentPanel)
        local profilerTable = blobsProfiler[luaState].Profile or {}
        local profilerData = table.Copy(profilerTable)
        profilerData.Raw = nil -- we dont need to display this

        blobsProfiler.buildDTree(luaState, parentPanel, "Profiling.Targets", profilerData)
    end
})

blobsProfiler.RegisterSubModule("Profiling", "Results", {
    Icon = "icon16/chart_bar.png",
    OrderPriority = 2
})