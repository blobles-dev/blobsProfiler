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

    end,
    PreloadClient = true,
    PreloadServer = false,
    BuildPanel = function(luaState, parentPanel)
		blobsProfiler.buildDTree(luaState, parentPanel, "SQLite.Schema")
    end,
    RefreshButton = "Refresh"
})

blobsProfiler.RegisterSubModule("SQLite", "Data", {
    Icon = "icon16/page_white_database.png",
    OrderPriority = 2,
})

blobsProfiler.RegisterSubModule("SQLite", "Execute", {
    Icon = "icon16/database_go.png",
    OrderPriority = 3,
})