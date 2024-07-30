blobsProfiler.RegisterModule("SQLite", {
    Icon = "icon16/database.png",
    OrderPriority = 8
})

local function buildSQLiteSchemaTable()
    local SQLiteSchema = {}
    SQLiteSchema.Tables = {}
    SQLiteSchema.Indices = {}

    local grabTableIndexData = sql.Query("SELECT * FROM sqlite_master")

    if grabTableIndexData then
        for _, tblData in ipairs(grabTableIndexData) do
			if tblData.type == "table" then
				SQLiteSchema.Tables[tblData.name] = {}
				local grabTableColumnData = sql.Query("PRAGMA table_info(".. sql.SQLStr(tblData.name) ..");")
				if grabTableColumnData then
					for _, tblCol in ipairs(grabTableColumnData) do
						SQLiteSchema.Tables[tblData.name][tblCol.cid] = {}
						SQLiteSchema.Tables[tblData.name][tblCol.cid]["ID"] = tblCol.cid
						SQLiteSchema.Tables[tblData.name][tblCol.cid]["Name"] = tblCol.name
						SQLiteSchema.Tables[tblData.name][tblCol.cid]["Primary Key"] = tobool(tblCol.pk) or nil
						SQLiteSchema.Tables[tblData.name][tblCol.cid]["Type"] = tblCol.type or nil
						SQLiteSchema.Tables[tblData.name][tblCol.cid]["Not NULL"] = tblCol.notnull or nil
						SQLiteSchema.Tables[tblData.name][tblCol.cid]["Default"] = tblCol.dflt_value or nil
					end
				end
			elseif tblData.type == "index" then
				SQLiteSchema.Indices[tblData.name] = {}
				--blobsProfiler.SQLite.SchemaIndices[v.name].CreateSQL = v.sql
			end
        end
    end

    return SQLiteSchema
end

blobsProfiler.RegisterSubModule("SQLite", "Schema", {
    Icon = "icon16/database_gear.png",
    OrderPriority = 1,
    UpdateRealmData = function(luaState)
        if luaState == "Client" then
            blobsProfiler.Client.SQLite = blobsProfiler.Client.SQLite or {}
            blobsProfiler.Client.SQLite.Schema = buildSQLiteSchemaTable()
        else
            net.Start("blobsProfiler:requestData")
                net.WriteString("SQLite.Schema")
            net.SendToServer()
        end
    end,
    PrepServerData = function()
        return buildSQLiteSchemaTable()
    end,
    PreloadClient = true,
    PreloadServer = false,
    BuildPanel = function(luaState, parentPanel)
		blobsProfiler.buildDTree(luaState, parentPanel, "SQLite.Schema")
    end,
    RefreshButton = "Refresh"
})

local function splitAndProcessQueries(query) -- why the fuck did I bother
    local results = {}
    local queries = string.Explode(";", query)

    for _, singleQuery in ipairs(queries) do
		singleQuery = string.Trim(singleQuery)

		if singleQuery ~= "" then
			local queryType = string.match(singleQuery:upper(), "^(%w+)")
			local result
			local affectedRowsStr
			local affectedRows

			if queryType == "SELECT" or queryType == "PRAGMA" or queryType == "EXPLAIN" then
				result = sql.Query(singleQuery)
				if result == false then
                    table.insert(results, {type = "ERROR", message=sql.LastError(), query = singleQuery})
                else
                    table.insert(results, {type = queryType, data = result, query = singleQuery})
                end
			elseif queryType == "INSERT" or queryType == "UPDATE" or queryType == "DELETE" then
				result = sql.Query(singleQuery)
				affectedRowsStr = sql.QueryValue("SELECT changes()")
				affectedRows = tonumber(affectedRowsStr) or 0
				if result == false then
					table.insert(results, {type = "ERROR", message = sql.LastError(), query = singleQuery})
				else
					table.insert(results, {type = queryType, message = "Rows affected: " .. affectedRows, rowsAffected = affectedRows, query = singleQuery})
				end
			elseif queryType == "COMMIT" or queryType == "ROLLBACK" or queryType == "CREATE" or queryType == "ALTER" or queryType == "DROP" then
				local success = sql.Query(singleQuery)
				if success == false then
					table.insert(results, {type = "ERROR", message = sql.LastError(), query = singleQuery})
				else
					table.insert(results, {type = queryType, message = queryType .. " operation successful", query = singleQuery})
				end
			elseif queryType == "SAVEPOINT" then
				local savepointName = string.match(singleQuery, "SAVEPOINT%s+([%w_]+)")
				if savepointName then
					local success = sql.Query("SAVEPOINT " .. savepointName)
					if success == false then
						table.insert(results, {type = "ERROR", message = sql.LastError(), query = singleQuery})
					else
						table.insert(results, {type = "SAVEPOINT", message = "Savepoint created: " .. savepointName, query = singleQuery})
					end
				else
					table.insert(results, {type = "ERROR", message = "Savepoint name not specified", query = singleQuery})
				end
			else
                local tryInvalid = sql.Query(singleQuery)

                if tryInvalid == false then
                    table.insert(results, {type = "ERROR", message = sql.LastError(), query = singleQuery})
                else
                    table.insert(results, {type = "ERROR", message = "UNHANDLED SQL QUERY TYPE: ".. queryType, query = singleQuery})
                end
			end
		end
    end

    return results
end

if SERVER then
    util.AddNetworkString("blobsProfiler:requestSQLiteData")

    net.Receive("blobsProfiler:requestSQLiteData", function(len, ply)
        if not blobsProfiler.CanAccess(ply, "serverData") then return end
        if not blobsProfiler.CanAccess(ply, "serverData_SQLite") then return end
        if not blobsProfiler.CanAccess(ply, "serverData_SQLite_Data") then return end

        local tableName = net.ReadString()
        local pageNum = net.ReadUInt(12)
        if pageNum < 1 then pageNum = 1 end

        local getSQLData = sql.Query("SELECT * FROM ".. sql.SQLStr(tableName) .. " LIMIT 25")
        if getSQLData == false then
            -- error
        elseif getSQLData == nil then
            -- no data
        else
            net.Start("blobsProfiler:requestSQLiteData")
                net.WriteString(tableName)
                net.WriteTable(getSQLData)
            net.Send(ply)            
        end
    end)

    util.AddNetworkString("blobsProfiler:runSQLite")

    net.Receive("blobsProfiler:runSQLite", function(len, ply)
        if not blobsProfiler.CanAccess(ply, "serverData") then return end
        if not blobsProfiler.CanAccess(ply, "serverData_SQLite") then return end
        if not blobsProfiler.CanAccess(ply, "serverData_SQLite_Execute") then return end

        local sqlQuery = net.ReadString()

        local proccessQuery = splitAndProcessQueries(sqlQuery)

        net.Start("blobsProfiler:runSQLite")
            net.WriteTable(proccessQuery or {}) -- todo: use chunked sending
        net.Send(ply)
    end)
else
    net.Receive("blobsProfiler:requestSQLiteData", function()
        local tableName = net.ReadString()
        local getSQLData = net.ReadTable()

        blobsProfiler.Modules.SQLite.SubModules.Data.retrievingData = false
        local schemaDataTable = blobsProfiler.Server.SQLite.Schema
        local tableSelectorList = blobsProfiler.Server.SQLite.Data.tableSelectorList
        local tableDataListView = blobsProfiler.Server.SQLite.Data.tableDataListView
        
        for k, line in ipairs( tableDataListView:GetLines() ) do
            tableDataListView:RemoveLine(k)
        end

        for k,v in ipairs(tableDataListView.Columns) do
            if v and IsValid(v) then v:Remove() end
        end

        tableDataListView.Columns = {}

        local colList = schemaDataTable.Tables[tableName]
        if colList then
            local colAmnt = table.Count(colList)
            for i=0, colAmnt-1 do
                local colData = schemaDataTable.Tables[tableName][i] -- why the fuck is it a number now
                tableDataListView:AddColumn(colData.Name)
            end
        end
        tableDataListView:SetDirty( true )
        
        tableDataListView:FixColumnsLayout()

        local tblOrder = {}
        local colList = schemaDataTable.Tables[tableName]
        if colList then
            local colAmnt = table.Count(colList)
            for i=0, colAmnt-1 do
                local colData = schemaDataTable.Tables[tableName][i]
                table.insert(tblOrder, colData.Name)
            end
        end

        for _, record in ipairs(getSQLData) do
            local dataBuild = {}
            for __, key in ipairs(tblOrder) do
                table.insert(dataBuild, record[key])
            end
            tableDataListView:AddLine(unpack(dataBuild))
        end
    end)

    net.Receive("blobsProfiler:runSQLite", function()
        local queryResults = net.ReadTable()

        local subModuleRef = blobsProfiler.Modules.SQLite.SubModules.Execute
        subModuleRef.ServerTab.handleQueries("Server", queryResults)
    end)
end

local function requestSQLiteData(luaState, tableName, pageNum)
    pageNum = pageNum or 1
    local schemaDataTable = blobsProfiler[luaState].SQLite.Schema

    local tableSelectorList = blobsProfiler[luaState].SQLite.Data.tableSelectorList
    local tableDataListView = blobsProfiler[luaState].SQLite.Data.tableDataListView

    if luaState == "Client" then
        for k, line in ipairs( tableDataListView:GetLines() ) do
            tableDataListView:RemoveLine(k)
        end

        for k,v in ipairs(tableDataListView.Columns) do
            if v and IsValid(v) then v:Remove() end
        end

        tableDataListView.Columns = {}

        local colList = schemaDataTable.Tables[tableName]
        if colList then
            local colAmnt = table.Count(colList)
            for i=0, colAmnt-1 do
                local colData = schemaDataTable.Tables[tableName][tostring(i)] -- TODO: make this actual number ffs
                tableDataListView:AddColumn(colData.Name)
            end
        end
        tableDataListView:SetDirty( true )
        
        tableDataListView:FixColumnsLayout()

        local getSQLData = sql.Query("SELECT * FROM ".. sql.SQLStr(tableName) .. " LIMIT 25")
        if getSQLData == false then
            -- error
        elseif getSQLData == nil then
            -- no data
        else

            local tblOrder = {}
            local colList = schemaDataTable.Tables[tableName]
            if colList then
                local colAmnt = table.Count(colList)
                for i=0, colAmnt-1 do
                    local colData = schemaDataTable.Tables[tableName][tostring(i)] -- TODO: make this actual number ffs
                    table.insert(tblOrder, colData.Name)
                end
            end

            for _, record in ipairs(getSQLData) do
                local dataBuild = {}
                for __, key in ipairs(tblOrder) do
                    table.insert(dataBuild, record[key])
                end
                tableDataListView:AddLine(unpack(dataBuild))
            end
            
        end
    else
        blobsProfiler.Modules.SQLite.SubModules.Data.retrievingData = true
        net.Start("blobsProfiler:requestSQLiteData")
            net.WriteString(tableName)
            net.WriteUInt(pageNum, 12)
        net.SendToServer()
    end
end

blobsProfiler.RegisterSubModule("SQLite", "Data", {
    Icon = "icon16/page_white_database.png",
    OrderPriority = 2,
    CustomPanel = function(luaState, parentPanel)
        blobsProfiler[luaState].SQLite = blobsProfiler[luaState].SQLite or {}

        blobsProfiler[luaState].SQLite.Data = blobsProfiler[luaState].SQLite.Data or {}

        local schemaDataTable = blobsProfiler[luaState].SQLite.Schema or {}
        
        blobsProfiler[luaState].SQLite.Data.tableSelectorList = vgui.Create("DComboBox", parentPanel)
        blobsProfiler[luaState].SQLite.Data.tableDataListView = vgui.Create("DListView", parentPanel)

        local tableSelectorList = blobsProfiler[luaState].SQLite.Data.tableSelectorList
        local tableDataListView = blobsProfiler[luaState].SQLite.Data.tableDataListView

        tableDataListView:Dock(FILL)

        tableSelectorList:Dock(TOP)
        tableSelectorList:SetSortItems(false)

        tableSelectorList.OnSelect = function(s, index, value)
            requestSQLiteData(luaState, value)
        end
        
        for k,v in pairs(schemaDataTable.Tables or {}) do
            tableSelectorList:AddChoice(k)
    
            if not tableSelectorList:GetSelected() then
                tableSelectorList:ChooseOption(k, 1)
            end
        end
    end,
    OnOpen = function(luaState)
        if blobsProfiler[luaState].SQLite.Data.tableSelectorList then

            blobsProfiler[luaState].SQLite.Data.tableSelectorList.Data = {}
            blobsProfiler[luaState].SQLite.Data.tableSelectorList.Choices = {}
            
            local schemaDataTable = blobsProfiler[luaState].SQLite.Schema or {}

            for k, v in pairs(schemaDataTable.Tables or {}) do
                blobsProfiler[luaState].SQLite.Data.tableSelectorList:AddChoice(k)
        
                if not blobsProfiler[luaState].SQLite.Data.tableSelectorList:GetSelected() then
                    blobsProfiler[luaState].SQLite.Data.tableSelectorList:ChooseOption(k, 1)
                end
            end
        end
    end
})

blobsProfiler.RegisterSubModule("SQLite", "Execute", {
    Icon = "icon16/database_go.png",
    OrderPriority = 3,
    CustomPanel = function(luaState, parentPanel)
        local dhtmlPanel = blobsProfiler.generateAceEditorPanel(parentPanel, "", "SQL")
        dhtmlPanel:Dock(FILL)

        local resultContainer = vgui.Create("DPropertySheet", parentPanel)
        resultContainer:SetVisible(false)

        local executeButton = vgui.Create("DButton", parentPanel)

        parentPanel.handleQueries = function(luaStateHQ, dataTable)
            local realmString = string.lower(luaStateHQ)
            if not blobsProfiler.CanAccess(ply, realmString .. "Data") then return end
            if not blobsProfiler.CanAccess(ply, realmString .. "Data_SQLite") then return end
            if not blobsProfiler.CanAccess(ply, realmString .. "Data_SQLite_Execute") then return end

            if resultContainer and IsValid(resultContainer) then
                resultContainer:Remove()
            end
            
            resultContainer = vgui.Create("DPropertySheet", parentPanel)
            resultContainer:SetVisible(false)

            for queryID, queryTable in ipairs(dataTable) do
                local queryType = queryTable.type or "ERROR"
                local isError = queryType == "ERROR" or false

                local panel1 = vgui.Create( "DPanel", resultContainer )

                if queryType == "ERROR" then -- TODO: some of this can be condensed
                    local queryResult = vgui.Create("DPanel", panel1)
                    queryResult:Dock(FILL)
                    queryResult.Paint = function(s,w,h) 
                        draw.SimpleTextOutlined(queryTable.query, "DermaDefault", 5, 2, Color(255,80,80), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_black)
                        draw.SimpleText(queryTable.message or "Unknown Error", "DermaDefault", 5, 20, color_black, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    end
                elseif queryType == "SELECT" or queryType == "PRAGMA" or queryType == "EXPLAIN" then
                    local queryResult = vgui.Create("DListView", panel1)
                    queryResult:Dock(FILL)

                    if queryTable.data and #queryTable.data >= 1 then
                        local keys = table.GetKeys(queryTable.data[1]) -- idk if this is good enough
                        for _, keyName in ipairs(keys) do
                            queryResult:AddColumn(keyName)
                        end

                        for i, tblRecord in ipairs(queryTable.data) do
                            local lineData = {}
                            for _, key in ipairs(keys) do
                                table.insert(lineData, tblRecord[key])
                            end
                            queryResult:AddLine(unpack(lineData))
                        end
                    end

                    local querySummary = vgui.Create("DPanel", panel1)
                    querySummary:SetTall(20)
                    if queryType == "SELECT" and queryTable.data then
                        querySummary:SetTall(32)
                    end
                    querySummary:Dock(TOP)
                    querySummary.Paint = function(s,w,h)
                        draw.SimpleTextOutlined(queryTable.query, "DermaDefault", 5, 2, Color(0,255,0), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_black)
                        if queryType == "SELECT" and queryTable.data then
                            draw.SimpleText("Rows: " .. (queryTable.data and #queryTable.data or "0"), "DermaDefault", 5, 16, color_black, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        end
                    end
                elseif queryType == "INSERT" or queryType == "UPDATE" or queryType == "DELETE"
                or  queryType == "COMMIT" or queryType == "ROLLBACK" or queryType == "CREATE" or queryType == "ALTER" or queryType == "DROP"
                or queryType == "SAVEPOINT" then
                    local queryResult = vgui.Create("DPanel", panel1)
                    queryResult:Dock(FILL)
                    queryResult.Paint = function(s,w,h) 
                        draw.SimpleTextOutlined(queryTable.query, "DermaDefault", 5, 2, Color(0,255,0), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_black)
                        draw.SimpleText(queryTable.message, "DermaDefault", 5, 16, color_black, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    end
                else
                    --- ???
                    blobsProfiler.Log(blobsProfiler.L_NH_ERROR, "Unhandled SQL query type: ".. (queryTable.type or "UNKNOWN"))
                    PrintTable(queryTable)
                end

                local qTab
                if isError then
                    qTab = resultContainer:AddSheet( "Query "..queryID, panel1, "icon16/database_error.png")
                    qTab.Tab.PaintOver = function(self, w, h)                        
                        surface.SetDrawColor(255, 0, 0, 50)
                        surface.DrawRect(0, 0, w, h)
                    end
                else
                    qTab = resultContainer:AddSheet( "Query "..queryID, panel1, "icon16/database.png")
                end

                qTab.Tab:SetTooltip(queryTable.query)
            end

            resultContainer:SetVisible(true)
            resultContainer:Dock(BOTTOM)
            resultContainer:SetTall(200)
            executeButton:Dock(BOTTOM)
        end

        dhtmlPanel:AddFunction("gmod", "receiveEditorContent", function(value)
            if luaState == "Client" then -- 'data' indicates a response from SV, ASSUME SV IF data IS PASSED!
                local results = splitAndProcessQueries(value)
                parentPanel.handleQueries("Client", results)
            elseif luaState == "Server" then
                net.Start("blobsProfiler:runSQLite")
                    net.WriteString(value)
                net.SendToServer()
            end
        end)
        
        executeButton:Dock(BOTTOM)
        executeButton:SetText("Execute SQL")

        executeButton.DoClick = function()
            dhtmlPanel:RunJavascript([[
                var value = getEditorValue();
                gmod.receiveEditorContent(value);
            ]])
        end
    end
})