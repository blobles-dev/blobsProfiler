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
    OrderPriority = 5,
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
    RefreshButton = "Re-scan",
    RCFunctions = {
        ["table"] = {
            {
                name = "Expand/Collapse",
                func = function(ref, node)
                    node:ExpandRecurse(not node:GetExpanded())
                    -- it's ok to use the ExpandRecurse here, not as bad as global tables.
                end,
                icon = "icon16/folder_explore.png"
            },
            {
                name = "Print path",
                func = function(ref, node)
                    local path = ""
                    local function apparentParentDir(child)
                        if child.parentNode then
                            path = child.Label:GetText() .. (path ~= "" and "/" or "") .. path
                            apparentParentDir(child.parentNode)
                        else
                            path = child:GetText() .. "/" .. path
                        end
                    end
                    
                    apparentParentDir(node)
    
                    print(path)
                end,
                icon = "icon16/application_osx_terminal.png"
            },
            {
                name = "Copy path",
                func = function(ref, node)
                    local path = ""
                    local function apparentParentDir(child)
                        if child.parentNode then
                            path = child.Label:GetText() .. (path ~= "" and "/" or "") .. path
                            apparentParentDir(child.parentNode)
                        else
                            path = child:GetText() .. "/" .. path
                        end
                    end
                    
                    apparentParentDir(node)
    
                    SetClipboardText(path)
                end,
                icon = "icon16/page_copy.png"
            }
        },
        ["string"] = {
            {
                name = "View source",
                func = function(ref, node)
                    local path = ""
                    local function apparentParentDir(child)
                        if child.parentNode then
                            path = child.Label:GetText() .. (path ~= "" and "/" or "") .. path
                            apparentParentDir(child.parentNode)
                        else
                            path = child:GetText() .. "/" .. path
                        end
                    end
                    
                    apparentParentDir(node)
    
                    net.Start("blobsProfiler:requestSource")
                        net.WriteString(path)
                    net.SendToServer()
                end,
                icon = "icon16/script_code.png"
            },
            {
                name = "Print path",
                func = function(ref, node)
                    local path = ""
                    local function apparentParentDir(child)
                        if child.parentNode then
                            path = child.Label:GetText() .. (path ~= "" and "/" or "") .. path
                            apparentParentDir(child.parentNode)
                        else
                            path = child:GetText() .. "/" .. path
                        end
                    end
                    
                    apparentParentDir(node)
    
                    print(path)
                end,
                icon = "icon16/application_osx_terminal.png"
            },
            {
                name = "Copy path",
                func = function(ref, node)
                    local path = ""
                    local function apparentParentDir(child)
                        if child.parentNode then
                            path = child.Label:GetText() .. (path ~= "" and "/" or "") .. path
                            apparentParentDir(child.parentNode)
                        else
                            path = child:GetText() .. "/" .. path
                        end
                    end
                    
                    apparentParentDir(node)
    
                    SetClipboardText(path)
                end,
                icon = "icon16/page_copy.png"
            }
        }
    },
    FormatNodeName = function(luaState, nodeKey, nodeValue)
        return istable(nodeValue) and nodeKey or nodeValue
    end
})