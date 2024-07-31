blobsProfiler = blobsProfiler or {}

blobsProfiler.Client = blobsProfiler.Client or {}
blobsProfiler.Server = blobsProfiler.Server or {}

blobsProfiler.DebugMode = true -- This is currently only used by the logger

blobsProfiler.L_NH_ERROR = -2 -- Throw error, no halt
blobsProfiler.L_ERROR = -1 -- Throws error
blobsProfiler.L_DEBUG = 0 -- For debug messages (can be hidden with DebugMode = false)
blobsProfiler.L_LOG = 1 -- Prints, but also stores
blobsProfiler.L_INFO = 2 -- Prints


--[[
        blobsProfiler.Log(<optional> number lLevel, string lMessage, <optional> string lSendToServer, <optional> bool lErrNHStack)
        - Logs a lMessage with the lLevel type on lRealm(s)

            <optional> number lLevel: The log level, available values: blobsProfiler.L_* (DEFAULT: blobsProfiler.L_INFO)
            string lMessage: The message to actually log 
            <optional> bool lSendToServer: Send log to server (DEFAULT: false) has no effect when used on server realm.
            <optional> bool lErrStack: Set to true to provide the error stack, only works with error log types (DEFAULT: false)
        
        Examples: -- I think I covered every case?
            blobsProfiler.Log("Test message")
            blobsProfiler.Log("Test message", true)
            blobsProfiler.Log("Test message", false, true)
            blobsProfiler.Log(blobsProfiler.L_DEBUG, "Test message with debug")
            blobsProfiler.Log(blobsProfiler.L_DEBUG, "Test message with debug to server", true)
]]
blobsProfiler.Log = function(lLevel, lMessage, lSendToServer, lErrStack) -- TODO: send to server
    -- The shit we're about to do for variable arguments..
    if type(lLevel) == "string" and type(lMessage) == "boolean" then -- blobsProfiler.Log(lMessage, lSendToServer) / blobsProfiler.Log(lMessage, lSendToServer, lErrStack)
        lSendToServer = lMessage
        lMessage = lLevel
        lLevel = blobsProfiler.L_INFO
        lErrStack = lSendToServer or false
    elseif type(lLevel) == "string" then -- blobsProfiler.Log(lMessage)
        lMessage = lLevel
        lLevel = blobsProfiler.L_INFO
        lSendToServer = false
        lErrStack = false
    elseif type(lLevel) == "number" then -- Standard parameters
        if type(lMessage) ~= "string" then
            error("\nblobsProfiler.Log: Invalid parameters")
        end
        lSendToServer = lSendToServer or false
        lErrStack = lErrStack or false
    else
        error("\nblobsProfiler.Log: Invalid parameters")
    end

    local curTime = os.date("%H:%M:%S") -- tHaNK gOd lUa is caSe sEnSitiVE
    if lLevel == blobsProfiler.L_NH_ERROR then
        if lErrStack then
            ErrorNoHaltWithStack(string.format("[%s] [ERROR_S] blobsProfiler: %s", curTime, lMessage), 2)
        else
            ErrorNoHalt(string.format("[%s] [ERROR] blobsProfiler: %s\n", curTime, lMessage))
        end
    elseif lLevel == blobsProfiler.L_ERROR then
        if lErrStack then
            error(string.format("\n[%s] [CRITICAL_S] blobsProfiler: %s", curTime, lMessage), 2)
        else
            Error(string.format("[%s] [CRITICAL] blobsProfiler: %s\n", curTime, lMessage))
        end
    elseif lLevel == blobsProfiler.L_DEBUG and blobsProfiler.DebugMode then
        print(string.format("[%s] [DEBUG] blobsProfiler: %s", curTime, lMessage))
    elseif lLevel == blobsProfiler.L_LOG then
        print(string.format("[%s] [LOG] blobsProfiler: %s", curTime, lMessage))
        -- TODO: Store it
    else -- Default / Generic
        print(string.format("[%s] [INFO] blobsProfiler: %s", curTime, lMessage))
    end
end

blobsProfiler.CanAccess = function(cPly, cArea, cRealm)
    return cPly:IsUserGroup("superadmin") -- TODO
end

blobsProfiler.SetRealmData = function(luaState, moduleName, dataTable)
    blobsProfiler.Log(blobsProfiler.L_DEBUG, "Setting " .. moduleName .. " ".. luaState .. " data")
	blobsProfiler[luaState] = blobsProfiler[luaState] or {}
    
    local moduleSplit = string.Explode(".", moduleName) -- [1] is parent, [2] is submodule
    
	if #moduleSplit == 1 then -- ew
        blobsProfiler[luaState][moduleSplit[1]] = dataTable
    else
        blobsProfiler[luaState][moduleSplit[1]] = blobsProfiler[luaState][moduleSplit[1]] or {}
        blobsProfiler[luaState][moduleSplit[1]][moduleSplit[2]] = dataTable
    end
end

blobsProfiler.GetDataTableForRealm = function(luaState, rvarType)
    blobsProfiler[luaState] = blobsProfiler[luaState] or {}

	local moduleSplit = string.Explode(".", rvarType)

	if #moduleSplit == 1 then -- ew
		return blobsProfiler[luaState][moduleSplit[1]] or {} -- brother ewwww
    else
        blobsProfiler[luaState][moduleSplit[1]] = blobsProfiler[luaState][moduleSplit[1]] or {}
        return blobsProfiler[luaState][moduleSplit[1]][moduleSplit[2]] or {} ---  what is that brother
    end

    return blobsProfiler[luaState][rvarType] or {}
end

blobsProfiler.TableSort = {}
blobsProfiler.TableSort.KeyAlphabetical = function(t)
    local keys = {}
    
    for key in pairs(t) do
        table.insert(keys, key)
    end
    
    table.sort(keys, function(a, b)
        return a < b
    end)
    
    local sortedTable = {}
    
    for _, key in ipairs(keys) do
        sortedTable[key] = t[key]
    end
    
    return sortedTable
end
blobsProfiler.TableSort.ByIndex = function(t, i)
    return table.sort(t, function(a, b)
        return a[i] < b[i]
    end)
end
blobsProfiler.TableSort.SQLTableColSort = function(parentTable)
    local parentKeys = {}
    for parentKey in pairs(parentTable) do
        table.insert(parentKeys, parentKey)
    end

    table.sort(parentKeys)

    local sortedParentTable = {}
    for _, parentKey in ipairs(parentKeys) do
        local childTable = parentTable[parentKey]

        local childKeys = {}
        for childKey in pairs(childTable) do
            table.insert(childKeys, childKey)
        end

        table.sort(childKeys, function(a, b)
            return childTable[a].ID < childTable[b].ID
        end)

        local sortedChildTable = {}
        for _, childKey in ipairs(childKeys) do
            sortedChildTable[childKey] = childTable[childKey]
        end

        sortedParentTable[parentKey] = sortedChildTable
    end

    return sortedParentTable
end