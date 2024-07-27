blobsProfiler = blobsProfiler or {}
blobsProfiler.Modules = blobsProfiler.Modules or {}

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
	},
}

blobsProfiler.LoadFiles = function()
	for _, fileList in ipairs(blobsProfiler.FileList) do
		incFile(fileList.File, fileList.CL, fileList.SV)
	end
end

blobsProfiler.LoadFiles()

blobsProfiler.LoadModule = function(ModuleName)
	local moduleName = string.lower(ModuleName)
	if SERVER then
		AddCSLuaFile("blobsprofiler/shared/modules/bp_" .. moduleName .. ".lua")
	end
	include("blobsprofiler/shared/modules/bp_" .. moduleName .. ".lua")
end

--[[
Lua
Hooks
ConCommands
Files
Network
Timers
SQLite
]]

blobsProfiler.LoadModule("Lua")
blobsProfiler.LoadModule("Hooks")
blobsProfiler.LoadModule("ConCommands")
blobsProfiler.LoadModule("Files")
blobsProfiler.LoadModule("Network")
blobsProfiler.LoadModule("Timers")
blobsProfiler.LoadModule("SQLite")