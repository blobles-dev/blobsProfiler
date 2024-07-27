blobsProfiler = blobsProfiler or {}

blobsProfiler.Restrictions = blobsProfiler.Restrictions or {}
blobsProfiler.Restrictions.Global = blobsProfiler.Restrictions.Global or {}
blobsProfiler.Restrictions.Function = blobsProfiler.Restrictions.Function or {}
blobsProfiler.Restrictions.Hook = blobsProfiler.Restrictions.Hook or {}
blobsProfiler.Restrictions.Concommand = blobsProfiler.Restrictions.Concommand or {}

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

-- TODO:
-- Complete todo list
-- Prevent blobsProfiler.Restrictions modification outside of this file

blobsProfiler.RestrictAccess = function(rType, rValue, rMethod) -- Legacy?
    -- STRING rType = Global, Function, Hook, Concommand
    -- STRING rValue = "functionName (or path i.e myGlobal.functionName)"
    -- STRING or TABLE rMethod = Type of method to restrict (Read, Write, Delete) - * can be used in place of a table containing all methods

    --[[
        'Read'
                READ: Deny
                WRITE: Deny
                DELETE: Deny
        'Write'
                READ: Allow
                WRITE: Deny
                DELETE: Deny
        'Delete'
                READ: Allow
                WRITE: Allow
                DELETE: Deny
    ]]

    if not rType or type(rType) ~= "string" or not table.HasValue({"Globals", "Function", "Hook", "Concommand"}, rType) then
        error("blobsProfiler.RestrictAccess: Invalid rType provided '".. rType .."'\nAllowed string values: Global, Function, Hook, Concommand")
    end
    if not rMethod then -- Type is checked later on
        error("blobsProfiler.RestrictAccess: rMethod not provided")
    end
    if not rValue or type(rValue) ~= "string" then
        error("blobsProfiler.RestrictAccess: Invalid rValue provided")
    end

    local restrictMethods = {}
    restrictMethods["Read"] = false
    restrictMethods["Write"] = false
    restrictMethods["Delete"] = false

    if type(rMethod) == "string" then
        rMethod = string.lower(rMethod)

        if rMethod == "*" then
            restrictMethods["Read"] = true
            restrictMethods["Write"] = true
            restrictMethods["Delete"] = true
        elseif rMethod == "read" then
            restrictMethods["Read"] = true
        elseif rMethod == "write" then
            restrictMethods["Write"] = true
        elseif rMethod == "delete" then
            restrictMethods["Delete"] = true
        else
            error("blobsProfiler.RestrictAccess: rMethod invalid string provided\nAllowed string values: Read, Write, Delete, *")
        end
    elseif type(rMethod) == "table" then
        for _, rM in ipairs(rMethod) do
            local rM = string.lower(rM)

            if rM == "read" then
                restrictMethods["Read"] = true
            end
            if rM == "write" then
                restrictMethods["Write"] = true
            end
            if rM == "read" then
                restrictMethods["Delete"] = true
            end
        end
    else
        error("blobsProfiler.RestrictAccess: Invalid rMethod type provided")
    end

    if blobsProfiler.Restrictions[rType][rValue] then
        print("blobsProfiler.RestrictAccess: rValue is already restricted")
        -- return
    end

    local dgiSource = debug.getinfo(2, "Sl")
    blobsProfiler.Restrictions[rType][rValue] = {
        Value = rValue,
        Restrict = restrictMethods,
        Restriction_Source = (dgiSource.short_src or "UNKNOWN_SOURCE") .. ":" .. (dgiSource.currentline or "UNKNOWN_LINE")
    }

    return true
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