blobsProfiler.RegisterModule("SQLite", {
    Icon = "icon16/database.png",
    OrderPriority = 7
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
})