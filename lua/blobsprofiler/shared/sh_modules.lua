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

blobsProfiler.GetModule = function(fullModuleName)
    local splitModuleName = string.Explode(".", fullModuleName)
    if not blobsProfiler.Modules[splitModuleName[1]] then return end
    
    if #splitModuleName == 1 then
        return blobsProfiler.Modules[splitModuleName[1]]
    else
        return blobsProfiler.Modules[splitModuleName[1]].SubModules[splitModuleName[2]], blobsProfiler.Modules[splitModuleName[1]]
    end
end

blobsProfiler.GetRCFunctionsTable = function(fullModuleName)
    local moduleTable = blobsProfiler.GetModule(fullModuleName)
    return moduleTable.RCFunctions or blobsProfiler.Menu.RCFunctions_DEFAULT
end