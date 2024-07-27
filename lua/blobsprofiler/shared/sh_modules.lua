blobsProfiler = blobsProfiler or {}
blobsProfiler.Modules = blobsProfiler.Modules or {}

blobsProfiler.RegisterModule = function(Name, ModuleConfig)
    blobsProfiler.Modules[Name] = ModuleConfig

    print("[blobsProfiler] Module: ".. Name .." - Loaded!")
end

blobsProfiler.RegisterSubModule = function(ParentModule, Name, ModuleConfig)
    blobsProfiler.Modules[ParentModule].SubModules = blobsProfiler.Modules[ParentModule].SubModules or {}
    blobsProfiler.Modules[ParentModule].SubModules[Name] = ModuleConfig

    print("[blobsProfiler] ".. ParentModule .." SubModule: ".. Name .." - Loaded!")
end