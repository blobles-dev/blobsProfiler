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

blobsProfiler.GetRCFunctionsTable = function(fullModule)
    local splitModuleName = string.Explode(".", fullModule)

    if #splitModuleName == 1 then
        return blobsProfiler.Modules[splitModuleName[1]].RCFunctions or blobsProfiler.Menu.RCFunctions_DEFAULT
    else
        return blobsProfiler.Modules[splitModuleName[1]].SubModules[splitModuleName[2]].RCFunctions or blobsProfiler.Menu.RCFunctions_DEFAULT
    end
end