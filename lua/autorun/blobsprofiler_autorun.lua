blobsProfiler = blobsProfiler or {}
blobsProfiler.Modules = blobsProfiler.Modules or {}

blobsProfiler.Client = blobsProfiler.Client or {}
blobsProfiler.Server = blobsProfiler.Server or {}

blobsProfiler.Client.Profile = blobsProfiler.Client.Profile or {}
blobsProfiler.Server.Profile = blobsProfiler.Server.Profile or {}

blobsProfiler.svDataChunkSize = 15000

local realmDataTable = {}

if SERVER then
    realmDataTable = blobsProfiler.Server
else
    realmDataTable = blobsProfiler.Client
end


MsgN("- blobsProfiler initializing files -")

local function incFile(fileData)
	local CL = fileData.CL or false
	local SV = fileData.SV or false
	local filePath = fileData.File or error("blobsProfiler: Failed to load file no .File provided!")

	if SV && SERVER && !CL then
		print("[blobsProfiler] SV Load: " .. filePath)
		include("blobsprofiler/" .. filePath)
	else
		if SERVER then
			print("[blobsProfiler] " .. (SV && "SH" || "CL") .. " DL: " .. filePath)
			AddCSLuaFile("blobsprofiler/" .. filePath)
		end

		if (SV && CL) || (CL && CLIENT) then
			print("[blobsProfiler] " .. (SV && "SH" || "CL") .. " Load: " .. filePath)
			if CLIENT and fileData.CL_NoInclude then print("[blobsProfiler] " .. (SV && "SH" || "CL") .. " CL_NoInclude: " .. filePath) return end
			include("blobsprofiler/" .. filePath)
		end
	end
end

blobsProfiler.FileList = {
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
		File = "shared/sh_blobsprofiler.lua",
		CL = true,
		SV = true,
	},
	{
		File = "shared/sh_modules.lua",
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
	}
}

blobsProfiler.LoadFiles = function()
	for _, fileData in ipairs(blobsProfiler.FileList) do
		incFile(fileData)
	end
end

blobsProfiler.LoadFiles()

blobsProfiler.LoadModules = function()
	local foundModuleFiles = file.Find("blobsprofiler/shared/modules/bp_*.lua", "LUA")

	for _, moduleLuaFile in ipairs(foundModuleFiles) do
		if SERVER then
			AddCSLuaFile("blobsprofiler/shared/modules/"..moduleLuaFile)
            blobsProfiler.Log(blobsProfiler.L_DEBUG, "Module AddCSLuaFile: ".. moduleLuaFile)
		end
		include("blobsprofiler/shared/modules/"..moduleLuaFile)
        blobsProfiler.Log(blobsProfiler.L_DEBUG, "Module include(): ".. moduleLuaFile)
	end
end

blobsProfiler.LoadModules()

local JSFiles = {
    { FileName = "ace", Parts = 8 },
    { FileName = "mode-sql" },
	{ FileName = "mode-glua", Parts = 4}
}

blobsProfiler.JSFileData = blobsProfiler.JSFileData or {}

blobsProfiler.LoadJSFiles = function()
    for _, JSFile in ipairs(JSFiles) do
        local basePath = "blobsProfiler/client/js/" .. JSFile.FileName
        local partCount = JSFile.Parts or 1
        local parts = {}

        for i = 1, partCount do
            local filePath = basePath .. (partCount > 1 and i or "") .. ".js.lua"
            if SERVER then
                AddCSLuaFile(filePath)
            else
                parts[i] = include(filePath)
            end
        end

        if not SERVER then
            blobsProfiler.JSFileData[JSFile.FileName] = table.concat(parts)
        end
    end
end

blobsProfiler.LoadJSFiles()