local localIncludedFiles = {}

local function normalizePath(filePath)
    return string.gsub(filePath, '\\', '/')
end

local scanNewFiles = {}
-- Function to recursively build nested tables for directories
local function addFileToTable(directoryTable, filePath)
    local parts = string.Explode("/", filePath)
    local currentTable = directoryTable
    
    for i = 1, #parts - 1 do
        local part = parts[i]
        currentTable[part] = currentTable[part] or {}
        currentTable = currentTable[part]
    end
    
    if not table.HasValue(currentTable, parts[#parts]) then
        table.insert(currentTable, parts[#parts])
		table.insert(scanNewFiles, filePath)
    end
end

local function scanTable(tbl, visited)
    for key, value in pairs(tbl) do
        if type(value) == "function" then
            local info = debug.getinfo(value, "S")
            if info and info.source and info.source:sub(1, 1) == "@" then
				local fullPath = info.source:sub(2)
				if string.EndsWith(fullPath, ".lua") then
					addFileToTable(localIncludedFiles, fullPath)
				end
            end
        elseif type(value) == "table" and not visited[value] then
            visited[value] = true
            scanTable(value, visited)
        end
    end
end

blobsProfiler.ScanGLoadedFiles = function()
	scanNewFiles = {}

    local visited = {}
    visited[_G] = true
    scanTable(_G, visited)

	return localIncludedFiles, scanNewFiles
end

blobsProfiler.RegisterModule("Files", {
    Icon = "icon16/folder_page.png",
    OrderPriority = 4,
    UpdateRealmData = function(luaState)
        if luaState == "Client" then
            local allFiles, newFiles = blobsProfiler.ScanGLoadedFiles()
    
            blobsProfiler.Client.Files = allFiles
        else
            net.Start("blobsProfiler:requestData")
                net.WriteString("Files")
            net.SendToServer()
        end
    end,
    PrepServerData = function()
        local allFiles, newFiles = blobsProfiler.ScanGLoadedFiles()

        return allFiles
    end,
    PreloadClient = true,
    PreloadServer = false,
    BuildPanel = function(luaState, parentPanel)
		blobsProfiler.buildDTree(luaState, parentPanel, "Files")
    end,
    RefreshButton = "Re-scan"
})