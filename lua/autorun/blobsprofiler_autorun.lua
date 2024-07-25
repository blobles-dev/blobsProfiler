blobsProfiler = blobsProfiler or {}

blobsProfiler.Client = blobsProfiler.Client or {}
blobsProfiler.Server = blobsProfiler.Server or {}

blobsProfiler.Client.Profile = blobsProfiler.Client.Profile or {}
blobsProfiler.Server.Profile = blobsProfiler.Server.Profile or {}

local realmDataTable = {}

if SERVER then
    realmDataTable = blobsProfiler.Server
else
    realmDataTable = blobsProfiler.Client
end

blobsProfiler.original_timerCreate = blobsProfiler.original_timerCreate or timer.Create

realmDataTable.includedFiles = realmDataTable.includedFiles or {}
realmDataTable.createdTimers = realmDataTable.createdTimers or {}

-- Function to normalize paths and construct full path
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

CDSIncTable = CDSIncTable or {}


function timer.Create(identifier, delay, reps, func)
	realmDataTable.createdTimers[identifier] = {
		["Delay: "..delay] = delay, -- kill me now
		["Repititions: "..reps] = reps or 0, -- kill me now
		["Function: "..tostring(func)] = func -- kill me now
	}

	return blobsProfiler.original_timerCreate(identifier, delay, reps, func)
end


MsgN("- blobsProfiler initializing files -")

local function incFile(path, CL, SV)
	if SV && SERVER && !CL then
		print("[blobsProfiler] SV Load: " .. path)
		include("blobsprofiler/" .. path)
	else
		if SERVER then
			print("[blobsProfiler] " .. (SV && "SH" || "CL") .. " DL: " .. path)
			AddCSLuaFile("blobsprofiler/" .. path)
		end

		if (SV && CL) || (CL && CLIENT) then
			print("[blobsProfiler] " .. (SV && "SH" || "CL") .. " Load: " .. path)
			include("blobsprofiler/" .. path)
		end
	end
end

blobsProfiler.FileList = {
	{
		File = "shared/sh_blobsprofiler.lua",
		CL = true,
		SV = true,
	},
	{
		File = "shared/sh_pon.lua",
		CL = true,
		SV = true,
	},
	{
		File = "shared/sh_netstream.lua",
		CL = true,
		SV = true,
	},
	{
		File = "client/cl_blobsprofiler.lua",
		CL = true
	},
	{
		File = "client/vgui/vgui_bpdtree.lua",
		CL = true
	},
	{
		File = "client/vgui/vgui_bpdtree_node.lua",
		CL = true
	},
	{
		File = "client/vgui/vgui_bpdtree_node_button.lua",
		CL = true
	},
	{
		File = "server/sv_blobsprofiler.lua",
		SV = true,
	},
}

blobsProfiler.LoadFiles = function()
	for _, fileList in ipairs(blobsProfiler.FileList) do
		incFile(fileList.File, fileList.CL, fileList.SV)
	end
end

blobsProfiler.LoadFiles()

-- Function to scan a table for functions and nested tables
local function scanTable(tbl, visited)
    for key, value in pairs(tbl) do
        if type(value) == "function" then
            local info = debug.getinfo(value, "S")
            if info and info.source and info.source:sub(1, 1) == "@" then
				local fullPath = info.source:sub(2)
				if string.EndsWith(fullPath, ".lua") then
					addFileToTable(realmDataTable.includedFiles, fullPath)
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

	return scanNewFiles
end