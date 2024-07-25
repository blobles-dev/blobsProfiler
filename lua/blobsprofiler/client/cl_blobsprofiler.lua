blobsProfiler = blobsProfiler or {}
-- <3 yogpod for the initial file tree viewer base && sparking the idea
-- https://gist.github.com/Yogpod/f3be860207bc71607f14225cd7a0c948
blobsProfiler.Menu = blobsProfiler.Menu or {}

--[[
TODO:
Double click for first RC option
Hooks: Suspend/Resume
More RC stuff
profiling
profiler results
SV data
Theming / dark theme (settings)
security
errors - sv/cl (player focus?)
convars
settings - disable individual modules
Refactoring - proper modularisation
sqlite - data pagination
sqlite - execute (ace editor, sql mode)
]]


--[[
	string, number, boolean,
	function, table, Angle,
	Vector, Player, Entity,
	Panel, IMaterial, ITexture,
	IMesh, CUserCmd, ConVar,
	nil, userdata, Vehicle
	Weapon, NPC, NextBot
	PhysObj, SaveRestore, EffectData
	Sound, Texture, NavArea
	Path, PhysicsCollide, Trace
	WeaponProficiency, ScriptedVehicle
]]

blobsProfiler.TypesToIcon = {
	["table"] = "folder",
	["function"] = "page_white_code",
	["IMaterial"] = "page_white_picture",
	["Panel"] = "page_white_paint",
	["Player"] = "page_white_world",
	["Entity"] = "page_white_world"
}

blobsProfiler.VarTypeIconOverride = {
	["SQL_Schema"] = {
		["table"] = "table"
	}
}

blobsProfiler.Menu.GlobalTypesToCondense = {
	{
		type = "string",
		prettyPlural = "Strings"
	},
	{
		type = "number",
		prettyPlural = "Numbers"
	},
	{
		type = "boolean",
		prettyPlural = "Booleans"
	},
	{
		type = "Panel",
		prettyPlural = "Panels"
	},
	{
		type = "function",
		prettyPlural = "Functions"
	},
	{
		type = "Entity",
		prettyPlural = "Entities"
	},
	{
		type = "Vector",
		prettyPlural = "Vectors"
	},
	{
		type = "Angle",
		prettyPlural = "Angles"
	},
	{
		type = "table",
		prettyPlural = "Tables"
	}
}

local function viewPropertiesPopup(title, data, width, height)
	local propertiesFrame = vgui.Create("DFrame")
	width = width or 500
	height = height or 500

	propertiesFrame:SetSize(width, height)
	propertiesFrame:SetTitle(title)
	propertiesFrame:Center()
	propertiesFrame:MakePopup()

	local propertiesList = vgui.Create("DProperties", propertiesFrame)
	propertiesList:Dock(FILL)

	for propertiesGroup, propertiesData in pairs(data) do
		for propertyKey, propertyValue in pairs(propertiesData) do
			local propertyRow = propertiesList:CreateRow(propertiesGroup, propertyKey)
			propertyRow:Setup("Generic")
			propertyRow:SetValue(tostring(propertyValue))
		end
	end

	return propertiesFrame
end

local function generateAceEditorPanel(parentPanel, content)
	local dhtmlPanel = vgui.Create("DHTML", parentPanel)
	content = content or [[print("Hello world!")]]

	dhtmlPanel:SetHTML([[
		<!DOCTYPE html>
		<html lang="en">
			<head>
				<meta charset="UTF-8">
				<title>blobsProfiler: Lua Execution</title>
				<style type="text/css" media="screen">
					#editor { 
					height: 400px; 
					width: 100%;
					}
				</style>
			</head>
			<body>
				<div id="editor">]].. content ..[[</div>
				<script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.4.13/ace.js" type="text/javascript" charset="utf-8"></script>
				<script src="https://cdn.hbn.gg/thirdparty/mode-glua.js" type="text/javascript"></script>
				<script>
					var editor = ace.edit("editor");
					editor.session.setMode("ace/mode/glua");
					editor.setOptions({
					enableBasicAutocompletion: true,
					enableSnippets: true,
					enableLiveAutocompletion: true,
					showLineNumbers: true,
					tabSize: 2
					});

					function getEditorValue() {
						return editor.getValue();
					}

					editor.commands.addCommand({
						name: "ignoreBacktick",
						bindKey: { win: "`", mac: "`" },
						exec: function(editor) {
							// Do nothing
						},
						readOnly: true // Disable this command in read-only mode
					});
				</script>
			</body>
		</html>
	]])

	return dhtmlPanel
end

local function popupSourceView(sourceContent, frameTitle)
	local sourceFrame = vgui.Create("DFrame")
	sourceFrame:SetSize(500,500)
	sourceFrame:SetTitle(frameTitle or "View source")
	sourceFrame:Center()
	sourceFrame:MakePopup()

	local sourcePanel = generateAceEditorPanel(sourceFrame, sourceContent)
	sourcePanel:Dock(FILL)
end

local receivedSource = {}

net.Receive("blobsProfiler:sendSourceChunk", function()
    local requestId = net.ReadString()
    local startPos = net.ReadUInt(32)
    local chunk = net.ReadString()

    if not receivedSource[requestId] then
        receivedSource[requestId] = {
            receivedSource = {},
            chunksReceived = 0
        }
    end

    local request = receivedSource[requestId]
    request.receivedSource[startPos] = chunk
    request.chunksReceived = request.chunksReceived + 1

    local combinedSource = ""
    local allChunksReceived = true
    local chunkSize = 30000

    for i = 1, request.chunksReceived * chunkSize, chunkSize do
        if request.receivedSource[i] then
            combinedSource = combinedSource .. request.receivedSource[i]
        else
            allChunksReceived = false
            break
        end
    end

    if allChunksReceived then
		local splitRequest = string.Explode(":", requestId)
		popupSourceView(combinedSource, splitRequest[1])

        receivedSource[requestId] = nil  -- Clean up the request data
    end
end)

local function stripFirstDirectoryFromPath(filePath) -- why does god hate me
	local newPath = filePath:match("^.-/(.*)")
	return newPath or filePath 
end

local function grabSourceFromFile(filePath, lineStart, lineEnd)
    local locations = {"GAME", "LUA", "MOD"}
    local findFile

    for _, location in ipairs(locations) do
        findFile = file.Open(filePath, "r", location)
        if findFile then
            break
        end
    end

    if not findFile then
        return nil
	end

    local content = {}
    local currentLine = 1

    while not findFile:EndOfFile() do
        local line = findFile:ReadLine()

        if currentLine >= lineStart and currentLine <= lineEnd then
            table.insert(content, line)
        end

        if currentLine > lineEnd then
            break
        end
		
        currentLine = currentLine + 1
    end

    findFile:Close()

    return table.concat(content, "\n")
end

blobsProfiler.Menu.RCFunctions = {}
blobsProfiler.Menu.RCFunctions["Global"] = {
	["string"] = {
		{
			name = "Print",
			func = function(ref, node)
				print(ref.value)
				print(node.GlobalPath)
			end,
			icon = "icon16/application_osx_terminal.png",
			requiredAccess = "Read"
		}
	},
	["number"] = {
		{
			name = "Print",
			func = function(ref, node)
				print(ref.value)
				print(node.GlobalPath)
			end,
			icon = "icon16/application_osx_terminal.png",
			requiredAccess = "Read"
		}
	},
	["boolean"] = {
		{
			name = "Print",
			func = function(ref, node)
				print(ref.value)
				print(node.GlobalPath)
			end,
			icon = "icon16/application_osx_terminal.png",
			requiredAccess = "Read"
		}
	},
	["table"] = {
		{
			name = "Print",
			func = function(ref, node)
				PrintTable(ref.value)
				print("Global Path:", node.GlobalPath)
				print("Restrictions:")
				PrintTable(node.Restrictions)
			end,
			icon = "icon16/application_osx_terminal.png",
			requiredAccess = "Read"
		}
	},
	["function"] = {
		{
			name = "View source",
			func = function(ref, node, luaState)
				if luaState == "Client" then
					local debugInfo = debug.getinfo(ref.value, "S")
					if not string.EndsWith(debugInfo.short_src, ".lua") then
						Derma_Message("Invalid function source: ".. debugInfo.short_src.."\nOnly functions defined in Lua can be read!", "Function view source", "OK")
						return
					end

					net.Start("blobsProfiler:requestSource")
						net.WriteString(debugInfo.short_src)
						net.WriteUInt(debugInfo.linedefined, 16)
						net.WriteUInt(debugInfo.lastlinedefined, 16)
					net.SendToServer()
				elseif luaState == "Server" then
					PrintTable(ref)
					net.Start("blobsProfiler:requestSource")
						net.WriteString(ref.value.source)
						net.WriteUInt(ref.value.linedefined, 16)
						net.WriteUInt(ref.value.lastlinedefined, 16)
					net.SendToServer()
				end
			end,
			icon = "icon16/magnifier.png"
		},
		{
			name = "View properties",
			func = function(ref, node, luaState)
				local propertiesData = {}

				if luaState == "Client" then
					local debugInfo = debug.getinfo(ref.value)
					propertiesData["debug.getinfo()"] = debugInfo
				elseif luaState == "Server" then
					propertiesData["debug.getinfo()"] = ref.value
				end
				
				local popupView = viewPropertiesPopup("View Function: " .. ref.key, propertiesData)
			end,
			icon = "icon16/magnifier.png"
		}
	}
}
blobsProfiler.Menu.RCFunctions["Hooks"] = blobsProfiler.Menu.RCFunctions["Global"]
blobsProfiler.Menu.RCFunctions["ConCommands"] = blobsProfiler.Menu.RCFunctions["Global"]
blobsProfiler.Menu.RCFunctions["Files"] = {
	["table"] = {
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
}
blobsProfiler.Menu.RCFunctions["Network"] = blobsProfiler.Menu.RCFunctions["Global"]
blobsProfiler.Menu.RCFunctions["Timers"] = {
	["table"] = { -- root node, timer identifier
		{
			name = "Print",
			func = function(ref, node)
				print(ref.value)
				print(node.GlobalPath)
			end,
			icon = "icon16/application_osx_terminal.png",
			requiredAccess = "Read"
		},
		{ -- Pause/Resume timer
			name = function(ref, node)
				if not timer.Exists(node.GlobalPath) then return end
				local timeLeft = timer.TimeLeft(node.GlobalPath)
				if timeLeft < 0 then
					return "Resume"
				else
					return "Pause"
				end
			end,
			func = function(ref, node)
				if not timer.Exists(node.GlobalPath) then return end
				local timeLeft = timer.TimeLeft(node.GlobalPath)
				if timeLeft < 0 then
					timer.UnPause(node.GlobalPath)
					node.Icon:SetImage("icon16/clock_stop.png")
				else
					timer.Pause(node.GlobalPath)
					node.Icon:SetImage("icon16/clock_play.png")
				end
			end,
			onLoad = function(ref, node)
				if not timer.Exists(node.GlobalPath) then return end
				local timeLeft = timer.TimeLeft(node.GlobalPath)
				if timeLeft < 0 then
					node.Icon:SetImage("icon16/clock_stop.png")
				else
					node.Icon:SetImage("icon16/clock_play.png")
				end
			end,
			icon = function(ref, node)
				if not timer.Exists(node.GlobalPath) then return end
				local timeLeft = timer.TimeLeft(node.GlobalPath)
				if timeLeft < 0 then
					return "icon16/clock_stop.png"
				else
					return "icon16/clock_play.png"
				end
			end,
			requiredAccess = "Write"
		},
		{ -- Delete timer
			name = function(ref, node)
				if not timer.Exists(node.GlobalPath) then node.Label:SetTextColor(Color(255,0,0)) return end
				return "Delete"
			end,
			func = function(ref, node)
				timer.Remove(node.GlobalPath)
				node.Label:SetTextColor(Color(255,0,0))
				node.Icon:SetImage("icon16/clock_delete.png")
			end,
			onLoad = function(ref, node)
				if not timer.Exists(node.GlobalPath) then
					node.Label:SetTextColor(Color(255,0,0))
					node.Icon:SetImage("icon16/clock_delete.png")
				end
			end,
			icon = "icon16/clock_delete.png",
			requiredAccess = "Delete"
		},
		{ -- Remove timer reference
			name = function(ref, node)
				if not timer.Exists(node.GlobalPath) then return "Remove reference" end
			end,
			func = function(ref, node)
				blobsProfiler.createdTimers[node.GlobalPath] = nil 
				node:Remove()
			end,
			icon = "icon16/clock_red.png",
			requiredAccess = "Delete"
		}
	}
}
blobsProfiler.Menu.RCFunctions["SQL_Schema"] = {
	["table"] = {
		{
			name = "SQL Create statement",
			submenu = {
				{
					name = "Print",
					func = function(ref, node)
						local grabSQLCreate = sql.QueryValue("SELECT sql FROM sqlite_master WHERE name = ".. sql.SQLStr(ref.key) .." LIMIT 1;")
						print(grabSQLCreate)
					end,
					icon = "icon16/application_osx_terminal.png"
				},
				{
					name = "Copy to clipboard",
					func = function(ref, node)
						local grabSQLCreate = sql.QueryValue("SELECT sql FROM sqlite_master WHERE name = ".. sql.SQLStr(ref.key) .." LIMIT 1;")
						SetClipboardText(grabSQLCreate)
					end,
					icon = "icon16/page_copy.png"
				}
			},
			icon = "icon16/table_lightning.png",
			condition = function(ref, node, realm)
				if not blobsProfiler[realm].SQLite.SchemaTables then return false end

				return blobsProfiler[realm].SQLite.SchemaTables[ref.key]
			end
		}
		--[[{
			name = "Expand children",
			func = function(ref, node)
				local function expandChildren(panel)
					if panel.Expander and (panel.GetExpanded and not panel:GetExpanded()) then
						panel.Expander:DoClick()
					end

					for k, v in pairs(panel:GetChildren()) do
						expandChildren(v)
					end
				end

				expandChildren(node)
			end,
			icon = "icon16/table_multiple.png"
		},
		{
			name = "Collapse children",
			func = function(ref, node)
				local function expandChildren(panel)
					if panel.Expander and (panel.GetExpanded and panel:GetExpanded()) then
						panel.Expander:DoClick()
					end

					for k, v in pairs(panel:GetChildren()) do
						expandChildren(v)
					end
				end

				expandChildren(node)
			end,
			icon = "icon16/table_multiple.png"
		},]]
	}
}

blobsProfiler.Menu.TypeFolders = {}

for k,v in ipairs(blobsProfiler.Menu.GlobalTypesToCondense) do
	blobsProfiler.Menu.TypeFolders[v.type] = true
end

local function nodeEntriesTableKeySort(a, b)
	local aIsTable = type(a.value) == 'table'
	local bIsTable = type(b.value) == 'table'
	if aIsTable && !bIsTable then
		return true
	elseif !aIsTable && bIsTable then
		return false
	else
		return a.key < b.key
	end
end

local function rootNodeEntriesTableKeySort(a, b)
	local aIsTable = type(a.value) == 'table'
	local bIsTable = type(b.value) == 'table'
	if !aIsTable && bIsTable then
		return true
	elseif aIsTable && !bIsTable then
		return false
	else
		return a.key < b.key
	end
end

local selectedNode = nil
local function addDTreeNode(parentNode, nodeData, specialType, isRoot, varType, luaState)
	local nodeKey = nodeData.key
	local nodeValue = nodeData.value
	local dataType = type(nodeValue)
	local iconOverride = nil

	local childNode

	local useParent = parentNode

	if isRoot && varType == "Global" then
		local dataType = type(nodeData.value)
		local specialFolderPanel = blobsProfiler.Menu.TypeFolders[dataType]
		if specialFolderPanel && type(specialFolderPanel) == "Panel" then
			useParent = specialFolderPanel
		end
	end

	if luaState == "Server" then
		if varType == "Hooks" && type(nodeValue) == "table" then
			if nodeValue.func then
				dataType = "function"
				iconOverride = "icon16/script_code.png"
			end
		end
	end

	if dataType == "table" then
		childNode = useParent:AddNode(nodeKey)
		childNode.Icon:SetImage(specialType && "icon16/folder_database.png" || "icon16/folder.png")

		if blobsProfiler.VarTypeIconOverride[varType] and blobsProfiler.VarTypeIconOverride[varType][dataType] then
			childNode.Icon:SetImage("icon16/" .. blobsProfiler.VarTypeIconOverride[varType][dataType] .. ".png")
		end

		childNode.oldExpand = childNode.SetExpanded
		
		childNode.NeedsLazyLoad = true -- TODO: add check to make sure there even is children?

		childNode.SetExpanded = function(...)
			if !childNode.LazyLoaded then
				-- Lazy loading!

				local grandchildNode = {}
			
				for key, value in pairs(nodeValue) do
					table.insert(grandchildNode, {
						key = key,
						value = value
					})
				end
			
				table.sort(grandchildNode, nodeEntriesTableKeySort)
			
				for index, gcNodeData in ipairs(grandchildNode) do
					addDTreeNode(childNode, gcNodeData, false, false, varType, luaState)
				end


				childNode.LazyLoaded = true
			end

			if blobsProfiler.Menu.RCFunctions[varType] and blobsProfiler.Menu.RCFunctions[varType][dataType] then				
				for k,v in ipairs(blobsProfiler.Menu.RCFunctions[varType][dataType]) do
					if v.requiredAccess and childNode.Restrictions[v.requiredAccess] then
						continue
					end
					if v.condition and not v.condition(nodeData, childNode, luaState) then
						continue
					end

					if v.onLoad then v.onLoad(nodeData, childNode) end
				end
			end

			childNode.oldExpand(...)
		end

		if varType == "SQL_Schema" then
			if nodeValue["ID"] or nodeValue["Default"] or nodeValue["Not NULL"] then -- TODO: Gotta be a better way to determine if this is a SQL table entry
				childNode.Label:SetText(nodeValue.Name)
			end
			if nodeValue["Primary Key"] then
				childNode.Icon:SetImage("icon16/table_key.png")
			end
		end
	else
		local nodeText = nodeKey
		if varType == "SQL_Schema" then
			nodeText = nodeKey .. ": " .. tostring(nodeValue)
		elseif varType == "Files" then
			nodeText = nodeValue
		end

		childNode = useParent:AddNode(nodeText)
		childNode.Icon:SetImage("icon16/".. (blobsProfiler.TypesToIcon[type(nodeValue)] || "page_white_text") ..".png")

		if blobsProfiler.VarTypeIconOverride[varType] and blobsProfiler.VarTypeIconOverride[varType][dataType] then
			childNode.Icon:SetImage("icon16/" .. blobsProfiler.VarTypeIconOverride[varType][dataType] .. ".png")
		end

		childNode.DoClick = function()
			if isRoot && useParent == parentNode && varType == "Global" then
				print("blobsProfiler: Non-foldered root for type: ".. type(nodeValue))
			end

			return true
		end

	end

	childNode.GlobalPath = childNode.GlobalPath || ""
	childNode.Restrictions = childNode.Restrictions || {}

	if not nodeData.special then
		if isRoot then
			childNode.GlobalPath = nodeKey
		else
			childNode.GlobalPath = parentNode.GlobalPath .. "." .. nodeKey
		end
	end

	varType = varType or "Global"

	if parentNode.Restrictions then
		childNode.Restrictions = parentNode.Restrictions
	end

	if blobsProfiler.Restrictions[varType] and blobsProfiler.Restrictions[varType][childNode.GlobalPath] then
		childNode.Restrictions = blobsProfiler.Restrictions[varType][childNode.GlobalPath].Restrict
	end

	if childNode.Restrictions and (childNode.Restrictions["Read"] or childNode.Restrictions["Write"] or childNode.Restrictions["Delete"]) then
		childNode.Label:SetTextColor(Color(200,190,0))

		local toolTipStr = "Read: ".. (childNode.Restrictions["Read"] and "NO" or "YES") .."\nWrite: ".. (childNode.Restrictions["Write"] and "NO" or "YES") .."\nDelete: ".. (childNode.Restrictions["Delete"] and "NO" or "YES")
		childNode:SetTooltip(toolTipStr)
	end

	childNode.DoRightClick = function()
		childNode:InternalDoClick()

		if blobsProfiler.Menu.RCFunctions[varType] and blobsProfiler.Menu.RCFunctions[varType][dataType] then
			blobsProfiler.Menu.RCMenu = DermaMenu()
			local RCMenu = blobsProfiler.Menu.RCMenu
			
			for _, rcM in ipairs(blobsProfiler.Menu.RCFunctions[varType][dataType]) do
				if rcM.requiredAccess and childNode.Restrictions[rcM.requiredAccess] then
					continue
				end
				if rcM.condition and not rcM.condition(nodeData, childNode, luaState) then
					continue
				end

				local useName = rcM.name
				if type(rcM.name) == "function" then
					useName = rcM.name(nodeData, childNode)
				end
				if useName then
					if rcM.submenu then
						local rcChild, rcParent = RCMenu:AddSubMenu(useName)

						local useIcon = rcM.icon
						if type(rcM.icon) == "function" then
							useIcon = rcM.icon(nodeData, childNode)
						end
						if useIcon then rcParent:SetIcon(useIcon) end

						for _, rcMS in ipairs(rcM.submenu) do
							if rcMS.requiredAccess and childNode.Restrictions[rcMS.requiredAccess] then
								continue
							end
							if rcMS.condition and not rcMS.condition(nodeData, childNode, luaState) then
								continue
							end

							local useNameSM = rcMS.name
							if type(rcMS.name) == "function" then
								useNameSM = rcMS.name(nodeData, childNode)
							end
							if useNameSM then
								local rcChildP = rcChild:AddOption(useNameSM, function()
									rcMS.func(nodeData, childNode, luaState)
									if rcMS.onLoad then
										rcMS.onLoad(nodeData, childNode)
									end
								end)

								local useIconSM = rcMS.icon
								if type(rcMS.icon) == "function" then
									useIconSM = rcMS.icon(nodeData, childNode)
								end
								if useIconSM then rcChildP:SetIcon(useIconSM) end
							end
						end
					else
						local rcOption = RCMenu:AddOption(useName, function()
							rcM.func(nodeData, childNode, luaState)
							if rcM.onLoad then
								rcM.onLoad(nodeData, childNode)
							end
						end)

						local useIcon = rcM.icon
						if type(rcM.icon) == "function" then
							useIcon = rcM.icon(nodeData, childNode)
						end
						if useIcon then rcOption:SetIcon(useIcon) end
					end
				end
			end

			RCMenu:Open()
		end
	end

	if blobsProfiler.Menu.RCFunctions[varType] and blobsProfiler.Menu.RCFunctions[varType][dataType] then				
		for k,v in ipairs(blobsProfiler.Menu.RCFunctions[varType][dataType]) do
			if v.requiredAccess and childNode.Restrictions[v.requiredAccess] then
				continue
			end
			if v.condition and not v.condition(nodeData, childNode, luaState) then
				continue
			end

			if v.onLoad then v.onLoad(nodeData, childNode) end
		end
	end

	if not isRoot then
		childNode.parentNode = parentNode
	end

	if dataType and dataType == "function" then
		childNode.FunctionRef = {name=nodeKey, func=nodeValue, path = "_G." .. childNode.GlobalPath}
		childNode:SetForceShowExpander(true)
		childNode:IsFunc()

		blobsProfiler[luaState].Profile.Raw = blobsProfiler[luaState].Profile.Raw or {}
		childNode.Expander.OnChange = function(s, isChecked)
			blobsProfiler[luaState].Profile[varType] = blobsProfiler[luaState].Profile[varType] or {}
			
			if isChecked then
				blobsProfiler[luaState].Profile[varType][childNode.FunctionRef.path] = childNode.FunctionRef
				blobsProfiler[luaState].Profile.Raw[nodeValue] = true
			else
				blobsProfiler[luaState].Profile[varType][childNode.FunctionRef.path] = nil
				blobsProfiler[luaState].Profile.Raw[nodeValue] = false
			end
		end
	end

	childNode.DoClick = function() -- hacky asf
		-- Find the first available right click option and run the func method
		-- Todo add check for how long ago it was clicked
		if selectedNode and selectedNode == childNode then
			local dataType = type(nodeValue)
			if blobsProfiler.Menu.RCFunctions[varType] and blobsProfiler.Menu.RCFunctions[varType][dataType] then
				for _, rcM in ipairs(blobsProfiler.Menu.RCFunctions[varType][dataType]) do
					if rcM.requiredAccess and childNode.Restrictions[rcM.requiredAccess] then
						continue
					end
					if rcM.condition and not rcM.condition(nodeData, childNode, luaState) then
						continue
					end
	
					rcM.func(nodeData, childNode, luaState) -- this should be first one they have access to
					break
				end
			end
			selectedNode = nil
		else
			selectedNode = childNode
		end
	end

	if iconOverride then
		childNode.Icon:SetImage(iconOverride)
	end

	childNode.varType = varType

	return childNode
end

local function buildDTree(luaState, parentPanel, varType)
	local dTree = vgui.Create("BP_DTree", parentPanel)
	dTree:Dock(FILL)
	dTree:SetVisible(false)

	local rootNodes = {}

	local dataTable = blobsProfiler.GetDataTableForRealm(luaState, varType)

	if varType == "Global" then
		for key, value in pairs(dataTable) do
			table.insert(rootNodes, {
				key = key,
				value = value
			})
		end

		local specialNodes = {}

		for k,v in ipairs(blobsProfiler.Menu.GlobalTypesToCondense) do
			table.insert(specialNodes, {
				key = v.prettyPlural,
				value = {},
				special = v.type
			})
		end

		for index, nodeData in ipairs(specialNodes) do
			if blobsProfiler.Menu.TypeFolders[nodeData.special] == true then
				blobsProfiler.Menu.TypeFolders[nodeData.special] = addDTreeNode(dTree, nodeData, true, true, varType, luaState)
				blobsProfiler.Menu.TypeFolders[nodeData.special].nodeData = nodeData
			end
		end
	elseif varType == "Hooks" then
		for k, v in pairs(dataTable) do
			table.insert(rootNodes, {
				key = k,
				value = v
			})
		end
	elseif varType == "ConCommands" then
		for k, v in pairs(dataTable) do
			table.insert(rootNodes, {
				key = k,
				value = v
			})
		end
	elseif varType == "Files" then
		for k, v in pairs(dataTable) do
			table.insert(rootNodes, {
				key = k,
				value = v
			})
		end
	elseif varType == "Network" then
		for k, v in pairs(dataTable) do
			table.insert(rootNodes, {
				key = k,
				value = v
			})
		end
	elseif varType == "Timers" then
		for k, v in pairs(dataTable) do
			table.insert(rootNodes, {
				key = k,
				value = v
			})
		end
	end

	table.sort(rootNodes, nodeEntriesTableKeySort)

	local rootNodesLen = #rootNodes

	for index, nodeData in ipairs(rootNodes) do
		addDTreeNode(dTree, nodeData, false, true, varType, luaState)

		if index == rootNodesLen then
			dTree:SetVisible(true)
		end
	end
end

local function buildSQLSchemaTab(luaState, parentPanel)
	local realmDataTable = blobsProfiler.GetDataTableForRealm(luaState, "SQL")

	local rootNodes = {}
	if realmDataTable.SchemaTables and realmDataTable.SchemaIndices then
		table.insert(rootNodes, {
			key = "Tables",
			value = blobsProfiler.TableSort.SQLTableColSort(realmDataTable.SchemaTables)
		})

		table.insert(rootNodes, {
			key = "Indices",
			value = blobsProfiler.TableSort.KeyAlphabetical(realmDataTable.SchemaIndices)
		})
	end
	--table.sort(rootNodes, rootNodeEntriesTableKeySort)

	local dTree = vgui.Create("BP_DTree", parentPanel)
	dTree:Dock(FILL)
	dTree:SetVisible(false)

	local rootNodesLen = #rootNodes

	for index, nodeData in ipairs(rootNodes) do
		addDTreeNode(dTree, nodeData, false, true, "SQL_Schema", luaState)

		if index == rootNodesLen then
			dTree:SetVisible(true)
		end
	end
end

local function buildSQLDataTab(luaState, parentPanel)
	local realmDataTable = blobsProfiler.GetDataTableForRealm(luaState, "SQL")

	local tableSelectorList = vgui.Create( "DComboBox", parentPanel )

	local tableDataListView = vgui.Create("DListView", parentPanel)
	tableDataListView:Dock(FILL)

	tableSelectorList:Dock(TOP)
	tableSelectorList:SetSortItems(false)

	tableSelectorList.OnSelect = function(s, index, value)
		for k, line in ipairs( tableDataListView:GetLines() ) do
			tableDataListView:RemoveLine(k)
		end

		for k,v in ipairs(tableDataListView.Columns) do
			if v and IsValid(v) then v:Remove() end
		end

		tableDataListView.Columns = {}

		local colList = realmDataTable.SchemaTables[value]
		if colList then
			local colAmnt = table.Count(colList)
			for i=0, colAmnt-1 do
				local colData = realmDataTable.SchemaTables[value][tostring(i)] -- TODO: make this actual number ffs
				tableDataListView:AddColumn(colData.Name)
			end
		end
		tableDataListView:SetDirty( true )
		
		tableDataListView:FixColumnsLayout()

		local getSQLData = sql.Query("SELECT * FROM ".. sql.SQLStr(value) .. " LIMIT 25")
		if getSQLData == false then
			-- error
		elseif getSQLData == nil then
			-- no data
		else

			local tblOrder = {}
			local colList = realmDataTable.SchemaTables[value]
			if colList then
				local colAmnt = table.Count(colList)
				for i=0, colAmnt-1 do
					local colData = realmDataTable.SchemaTables[value][tostring(i)] -- TODO: make this actual number ffs
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
	end

	for k,v in pairs(realmDataTable.SchemaTables or {}) do
		tableSelectorList:AddChoice(k)

		if not tableSelectorList:GetSelected() then
			tableSelectorList:ChooseOption(k, 1)
		end
	end
end

local function buildSQLTab(luaState, parentPanel)
	--local sqlTabMenu = vgui.Create( "DPropertySheet", parentPanel)
	--sqlTabMenu:Dock( FILL )

	local tabSchema = vgui.Create( "DPanel", parentPanel )
	parentPanel:AddSheet( "Schema", tabSchema, "icon16/database_gear.png" )
	buildSQLSchemaTab(luaState, tabSchema)

	local tabData = vgui.Create( "DPanel", parentPanel )
	parentPanel:AddSheet( "Data", tabData, "icon16/page_white_database.png" )
	buildSQLDataTab(luaState, tabData)

	local tabExecute = vgui.Create( "DPanel", parentPanel )
	parentPanel:AddSheet( "Execute", tabExecute, "icon16/database_go.png" )
end

local function luaExecutePanel(luaState, parentPanel)  -- TODO: server execution

	local dhtmlPanel = generateAceEditorPanel(parentPanel, content)

	dhtmlPanel:Dock(FILL)

	dhtmlPanel:AddFunction("gmod", "receiveEditorContent", function(value)
		RunString(value)
	end)


    local executeButton = vgui.Create("DButton", parentPanel)
    executeButton:Dock(BOTTOM)
    executeButton:SetText("Execute Lua Code")
    executeButton:DockMargin(0, 5, 0, 0)

    executeButton.DoClick = function()
		dhtmlPanel:RunJavascript([[
			var value = getEditorValue();
			gmod.receiveEditorContent(value);
		]])
    end
end

local function buildLuaTab(luaState, parentPanel)
	local tabGlobals = vgui.Create( "DPanel", parentPanel )
	parentPanel:AddSheet( "Globals", tabGlobals, "icon16/page_white_world.png" )
	buildDTree(luaState, tabGlobals, "Global")

	local tabExecute = vgui.Create( "DPanel", parentPanel )
	parentPanel:AddSheet( "Execute", tabExecute, "icon16/script_code.png" )
	luaExecutePanel(luaState, tabExecute)
end

if blobsProfiler.Menu.MenuFrame && IsValid(blobsProfiler.Menu.MenuFrame) then
	blobsProfiler.Menu.MenuFrame:Remove() -- kill on lua refresh
end

local function profileLog(realm, event)
	local luaCallInfo = debug.getinfo(3, "fnS")
	if not blobsProfiler.Client.Profile.Raw[luaCallInfo.func] then return end
	print(event, luaCallInfo.name, luaCallInfo.func, luaCallInfo.source)
end

blobsProfiler.Tabs = {}
blobsProfiler.Tabs.Client = {}
blobsProfiler.Tabs.Server = {}

concommand.Add("blobsprofiler", function(ply, cmd, args, argStr)
	if not blobsProfiler.CanAccess(LocalPlayer(), "OpenMenu") then return end -- TODO: better more modular permissions via settings

	if argStr == "reloadclient" then
		if blobsProfiler.Menu.MenuFrame or IsValid(blobsProfiler.Menu.MenuFrame) then
			blobsProfiler.Menu.MenuFrame:Remove()
			blobsProfiler.Menu.MenuFrame = nil
		end

		blobsProfiler.Client = {}
		blobsProfiler.DataTablesSetup = false

		blobsProfiler.LoadFiles()

		print("blobsProfiler: Reloaded client data & files")
		return
	end

	if not blobsProfiler.DataTablesSetup or argStr == "refresh" then
		blobsProfiler.InitOrSetupRealmDataTables()
		print("blobsProfiler: Refreshed data tables for: Client") -- this will always be on client lol
		
		if blobsProfiler.Menu.MenuFrame or IsValid(blobsProfiler.Menu.MenuFrame) then
			blobsProfiler.Menu.MenuFrame:Remove()
			blobsProfiler.Menu.MenuFrame = nil
		end
	end

	if blobsProfiler.Menu.MenuFrame && IsValid(blobsProfiler.Menu.MenuFrame) then
		if blobsProfiler.Menu.MenuFrame:IsVisible() then
			blobsProfiler.Menu.MenuFrame:Hide()
		else
			blobsProfiler.Menu.MenuFrame:Show()
		end

		return
	end
	
	blobsProfiler.Menu.TypeFolders = {}
	for k,v in ipairs(blobsProfiler.Menu.GlobalTypesToCondense) do
		blobsProfiler.Menu.TypeFolders[v.type] = true
	end

	blobsProfiler.Menu.selectedRealm = "Client"
	blobsProfiler.Menu.MenuFrame = vgui.Create("DFrame")
	blobsProfiler.Menu.MenuFrame:SetSize(900, 550)
	blobsProfiler.Menu.MenuFrame:Center()
	blobsProfiler.Menu.MenuFrame:SetTitle("blobsProfiler - " .. blobsProfiler.Menu.selectedRealm)
	blobsProfiler.Menu.MenuFrame:MakePopup()
	blobsProfiler.Menu.MenuFrame:SetSizable(true)
	blobsProfiler.Menu.MenuFrame:SetMinWidth( blobsProfiler.Menu.MenuFrame:GetWide() )
	blobsProfiler.Menu.MenuFrame:SetMinHeight( blobsProfiler.Menu.MenuFrame:GetTall() )

	local tabMenu = vgui.Create( "DPropertySheet", blobsProfiler.Menu.MenuFrame)
	tabMenu:Dock( FILL )
	
	blobsProfiler.Menu.MenuFrame.ProfilerPanel = vgui.Create("DPanel", blobsProfiler.Menu.MenuFrame)
	local profilerPanel = blobsProfiler.Menu.MenuFrame.ProfilerPanel
	profilerPanel:Dock(RIGHT)
	profilerPanel:DockMargin(5, 10, 0, 0)
	profilerPanel:SetWide(250)

	local stopProfiling = vgui.Create("DButton", profilerPanel)
	stopProfiling:SetText("Stop Profiling")
	stopProfiling:Dock(BOTTOM)
	stopProfiling:SetTall(30)
	stopProfiling.DoClick = function()
		debug.sethook()
	end

	local startProfiling = vgui.Create("DButton", profilerPanel)
	startProfiling:SetText("Start Profiling")
	startProfiling:Dock(BOTTOM)
	startProfiling:SetTall(30)
	startProfiling.DoClick = function()
		debug.sethook(function(e) profileLog("Client", e) end, "cr")
	end
	
	local tabClient = vgui.Create("DPropertySheet", tabMenu)
	tabMenu:AddSheet("Client", tabClient, "icon16/application.png")

	local tabServer = vgui.Create("DPropertySheet", tabMenu)
	tabMenu:AddSheet("Server", tabServer, "icon16/application_xp_terminal.png")

	local tabSettings = vgui.Create("DPropertySheet", tabMenu)
	tabMenu:AddSheet("Settings", tabSettings, "icon16/cog.png")

	tabClient.OnActiveTabChanged = function(s, pnlOld, pnlNew)
		blobsProfiler.Menu.MenuFrame:SetTitle("blobsProfiler - " .. blobsProfiler.Menu.selectedRealm .. " - " .. pnlNew:GetText())
	end

	tabServer.OnActiveTabChanged = function(s, pnlOld, pnlNew)
		blobsProfiler.Menu.MenuFrame:SetTitle("blobsProfiler - " .. blobsProfiler.Menu.selectedRealm .. " - " .. pnlNew:GetText())
		if blobsProfiler.RequestData.Server[pnlNew:GetText()] and not blobsProfiler.Server[pnlNew:GetText()] then blobsProfiler.RequestData.Server[pnlNew:GetText()]() end
	end

	tabMenu.OnActiveTabChanged = function(s, pnlOld, pnlNew)
		blobsProfiler.Menu.selectedRealm = pnlNew:GetText()
		blobsProfiler.Menu.MenuFrame:SetTitle("blobsProfiler - " .. blobsProfiler.Menu.selectedRealm)

		local subActiveTab = pnlNew:GetPanel():GetActiveTab()
		local subPropertySheetText = ""
		if subActiveTab and subActiveTab:GetText() then
			subPropertySheetText = " - " .. subActiveTab:GetText()
		end
		blobsProfiler.Menu.MenuFrame:SetTitle("blobsProfiler - " .. blobsProfiler.Menu.selectedRealm .. subPropertySheetText)
	end


	local luaStates = {
		Client = tabClient,
		Server = tabServer
	}

	for luaState, statePanel in pairs(luaStates) do
		local tabLua = vgui.Create("DPropertySheet", statePanel)
		statePanel:AddSheet( "Lua", tabLua, "icon16/world.png" )
		buildLuaTab(luaState, tabLua)
		blobsProfiler.Tabs[luaState].Lua = tabLua
		
		local tabHooks = vgui.Create( "DPanel", statePanel )
		statePanel:AddSheet( "Hooks", tabHooks, "icon16/brick_add.png" )
		buildDTree(luaState, tabHooks, "Hooks")
		blobsProfiler.Tabs[luaState].Hooks = tabHooks

		local tabConcommands = vgui.Create( "DPanel", statePanel )
		statePanel:AddSheet( "ConCommands", tabConcommands, "icon16/application_xp_terminal.png" )
		buildDTree(luaState, tabConcommands, "ConCommands")
		blobsProfiler.Tabs[luaState].ConCommands = tabConcommands

		blobsProfiler.ScanGLoadedFiles()
		local tabFiles = vgui.Create( "DPanel", statePanel )
		statePanel:AddSheet( "Files", tabFiles, "icon16/folder_page.png" )
		buildDTree(luaState, tabFiles, "Files")
		blobsProfiler.Tabs[luaState].Files = tabFiles

		local fileRescan = vgui.Create("DButton", tabFiles)
		fileRescan:Dock(BOTTOM)
		fileRescan:SetText("Re-scan")
		fileRescan:SetTooltip("This will re-scan the global table for functions, retrieve their source file and add it to the list")
		fileRescan.DoClick = function()
			-- TODO client/server difference
			local newFiles = blobsProfiler.ScanGLoadedFiles()
			buildDTree(luaState, tabFiles, "Files")

			Derma_Message("Global scan complete, new files found: ".. #newFiles, "Global re-scan", "OK") -- TODO: better view of new files? idea: highlight dtree node different colour until hovered to 'acknowledge'
			if #newFiles > 0 then
				print("Re-scan new files found:")
				PrintTable(newFiles)
			end
		end

		local tabNetwork = vgui.Create( "DPanel", statePanel )
		statePanel:AddSheet( "Network", tabNetwork, "icon16/drive_network.png" )
		buildDTree(luaState, tabNetwork, "Network")
		blobsProfiler.Tabs[luaState].Network = tabNetwork

		local tabTimers = vgui.Create( "DPanel", statePanel )
		statePanel:AddSheet( "Timers", tabTimers, "icon16/clock.png" )
		buildDTree(luaState, tabTimers, "Timers")
		blobsProfiler.Tabs[luaState].Timers = tabTimers

		local tabSQL = vgui.Create( "DPropertySheet", statePanel )
		statePanel:AddSheet( "SQLite", tabSQL, "icon16/database.png" )
		buildSQLTab(luaState, tabSQL)
		blobsProfiler.Tabs[luaState].SQLite = tabSQL
	end

	tabMenu:OnActiveTabChanged(nil, tabMenu:GetActiveTab()) -- lol
end)

--[[net.Receive("blobsProfiler:requestData", function()
	if not blobsProfiler.CanAccess(LocalPlayer(), "serverData") then return end
	blobsProfiler.Log(blobsProfiler.L_DEBUG, "requestData NW")
	local dataModule = net.ReadString()

	blobsProfiler.Log(blobsProfiler.L_DEBUG, "Module: ".. dataModule)

	if dataModule == "Hooks" then
		blobsProfiler.Server.Hooks = net.ReadTable()

		buildDTree("Server", blobsProfiler.Tabs.Server.Hooks)
	end
end)]]

netstream.Hook("blobsProfiler:requestData", function(dataModule, dataTable)
	if not blobsProfiler.CanAccess(LocalPlayer(), "serverData") then return end

	blobsProfiler.Log(blobsProfiler.L_DEBUG, "requestData module: ".. dataModule)

	if dataModule == "Hooks" then
		blobsProfiler.Server.Hooks = dataTable

		buildDTree("Server", blobsProfiler.Tabs.Server.Hooks, "Hooks")
	end
end)