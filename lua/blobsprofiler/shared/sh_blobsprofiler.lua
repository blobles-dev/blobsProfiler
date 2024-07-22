blobsProfiler = blobsProfiler or {}

blobsProfiler.Restrictions = blobsProfiler.Restrictions or {}
blobsProfiler.Restrictions.Global = blobsProfiler.Restrictions.Global or {}
blobsProfiler.Restrictions.Function = blobsProfiler.Restrictions.Function or {}
blobsProfiler.Restrictions.Hook = blobsProfiler.Restrictions.Hook or {}
blobsProfiler.Restrictions.Concommand = blobsProfiler.Restrictions.Concommand or {}

blobsProfiler.Client = blobsProfiler.Client or {}
blobsProfiler.Server = blobsProfiler.Server or {}

blobsProfiler.InitSQLiteData = function()
    local rootDataTable = SERVER and blobsProfiler.Server or blobsProfiler.Client
    
    rootDataTable.SQLite = {}
    rootDataTable.SQLite.SchemaTables = {}
    rootDataTable.SQLite.SchemaIndices = {}

    local grabTableIndexData = sql.Query("SELECT * FROM sqlite_master")

    if grabTableIndexData then
        for _, tblData in ipairs(grabTableIndexData) do
			if tblData.type == "table" then
				rootDataTable.SQLite.SchemaTables[tblData.name] = {}
				local grabTableColumnData = sql.Query("PRAGMA table_info(".. sql.SQLStr(tblData.name) ..");")
				if grabTableColumnData then
					for _, tblCol in ipairs(grabTableColumnData) do
						rootDataTable.SQLite.SchemaTables[tblData.name][tblCol.cid] = {}
						rootDataTable.SQLite.SchemaTables[tblData.name][tblCol.cid]["ID"] = tblCol.cid
						rootDataTable.SQLite.SchemaTables[tblData.name][tblCol.cid]["Name"] = tblCol.name
						rootDataTable.SQLite.SchemaTables[tblData.name][tblCol.cid]["Primary Key"] = tobool(tblCol.pk) or nil
						rootDataTable.SQLite.SchemaTables[tblData.name][tblCol.cid]["Type"] = tblCol.type or nil
						rootDataTable.SQLite.SchemaTables[tblData.name][tblCol.cid]["Not NULL"] = tblCol.notnull or nil
						rootDataTable.SQLite.SchemaTables[tblData.name][tblCol.cid]["Default"] = tblCol.dflt_value or nil
					end
				else
					print("blobsProfiler.InitSQLiteData: Unable to retrieve columns for SQLite table '".. tblData.name .."' (No columns/Error)")
				end
			elseif tblData.type == "index" then
				rootDataTable.SQLite.SchemaIndices[tblData.name] = {}
				--blobsProfiler.SQLite.SchemaIndices[v.name].CreateSQL = v.sql
			end
        end
    else
        error("blobsProfiler.InitSQLiteData: Failed to grab schema data from SQLite DB")
    end
end

blobsProfiler.InitOrSetupRealmDataTables = function() -- allows for init or refresh of data tables (except files or timers, due to how they work)
    if CLIENT then
        blobsProfiler.Client._G = table.Copy(_G)
        blobsProfiler.Client.Hooks = table.Copy(hook.GetTable())
        blobsProfiler.Client.ConCommands = table.Copy(concommand.GetTable())
        -- Files already initialised
        blobsProfiler.Client.Network = table.Copy(net.Receivers)
        -- Timers already initialised

        blobsProfiler.Server._G = {}
        blobsProfiler.Server.Hooks = {}
        blobsProfiler.Server.ConCommands = {}
        blobsProfiler.Server.includedFiles = {}
        blobsProfiler.Server.Network = {}
        blobsProfiler.Server.createdTimers = {}
        blobsProfiler.Server.SQLite = {}
    end

    if SERVER then
        blobsProfiler.Server._G = table.Copy(_G)
        blobsProfiler.Server.Hooks = table.Copy(hook.GetTable())
        blobsProfiler.Server.ConCommands = table.Copy(concommand.GetTable())
        -- Files already initialised
        blobsProfiler.Server.Network = table.Copy(net.Receivers)
        -- Timers already initialised

        -- TODO: Does the server even need access to the client data tables?
        blobsProfiler.Client._G = {}
        blobsProfiler.Client.Hooks = {}
        blobsProfiler.Client.ConCommands = {}
        blobsProfiler.Client.includedFiles = {}
        blobsProfiler.Client.Network = {}
        blobsProfiler.Client.createdTimers = {}
        blobsProfiler.Client.SQLite = {}
    end
    
    blobsProfiler.InitSQLiteData()

    blobsProfiler.DataTablesSetup = true
end

-- TODO:
-- Complete todo list
-- Prevent blobsProfiler.Restrictions modification outside of this file

blobsProfiler.RestrictAccess = function(rType, rValue, rMethod)
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

    if not rType or type(rType) ~= "string" or not table.HasValue({"Global", "Function", "Hook", "Concommand"}, rType) then
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

blobsProfiler.GetDataTableForRealm = function(luaState, dataType, forceRefresh)
    if luaState ~= "Client" and luaState ~= "Server" then return {} end

    if forceRefresh then blobsProfiler.InitOrSetupRealmDataTables() end

    if dataType == "*" then
        return blobsProfiler[luaState]
    elseif dataType == "Global" then
        return blobsProfiler[luaState]._G
    elseif dataType == "Hooks" then
        return blobsProfiler[luaState].Hooks
    elseif dataType == "ConCommands" then
        return blobsProfiler[luaState].ConCommands
    elseif dataType == "Files" then
        return blobsProfiler[luaState].includedFiles
    elseif dataType == "Network" then
        return blobsProfiler[luaState].Network
    elseif dataType == "Timers" then
        return blobsProfiler[luaState].createdTimers
    elseif dataType == "SQL" then
        return blobsProfiler[luaState].SQLite
    else
        return {}
    end
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

blobsProfiler.RestrictAccess("Global", "AO.AO", "*")
blobsProfiler.RestrictAccess("Global", "AO.AOCT", "*")
blobsProfiler.RestrictAccess("Global", "AO.AOFS", "Delete")

blobsProfiler.RestrictAccess("Global", "BlobsPartyConfig.AcceptReq", "*")
blobsProfiler.RestrictAccess("Global", "BlobsPartyConfig.FirstColor", "*")

blobsProfiler.RestrictAccess("Global", "angle_zero", "*")