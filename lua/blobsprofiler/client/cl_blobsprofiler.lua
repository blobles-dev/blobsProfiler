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

blobsProfiler.viewPropertiesPopup = function(title, data, width, height)
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

blobsProfiler.generateAceEditorPanel = function(parentPanel, content, editorMode)
	local dhtmlPanel = vgui.Create("DHTML", parentPanel)
	content = content or [[print("Hello world!")]]
	editorMode = editorMode or "Lua"
	local useMode = "ace/mode/glua"

	if editorMode == "SQL" then
		useMode = "ace/mode/sql"
	end

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
					editor.session.setMode("]].. useMode ..[[");
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

blobsProfiler.sourceFrames = {}

local function popupSourceView(sourceContent, frameTitle)
	local sourceFrame = vgui.Create("DFrame")
	sourceFrame:SetSize(500,500)
	sourceFrame:SetTitle(frameTitle or "View source")
	sourceFrame:Center()
	sourceFrame:MakePopup()

	local sourcePanel = blobsProfiler.generateAceEditorPanel(sourceFrame, sourceContent)
	sourcePanel:Dock(FILL)

	sourcePanel.OnRemove = function()
		blobsProfiler.sourceFrames[frameTitle] = nil
	end

	blobsProfiler.sourceFrames[frameTitle] = sourceFrame
end

local function killAllSourcePopups()
	for k,v in pairs(blobsProfiler.sourceFrames) do
		if IsValid(v) then
			v:Remove()
		end
	
		blobsProfiler.sourceFrames = {}
	end	
end
killAllSourcePopups()

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

blobsProfiler.Menu.RCFunctions = {}
blobsProfiler.Menu.RCFunctions_DEFAULT = {
	["string"] = {
		{
			name = "Print",
			func = function(ref, node)
				print(ref.value)
				print(node.GlobalPath)
			end,
			icon = "icon16/application_osx_terminal.png"
		}
	},
	["number"] = {
		{
			name = "Print",
			func = function(ref, node)
				print(ref.value)
				print(node.GlobalPath)
			end,
			icon = "icon16/application_osx_terminal.png"
		}
	},
	["boolean"] = {
		{
			name = "Print",
			func = function(ref, node)
				print(ref.value)
				print(node.GlobalPath)
			end,
			icon = "icon16/application_osx_terminal.png"
		}
	},
	["table"] = {
		{
			name = "Print",
			func = function(ref, node)
				PrintTable(ref.value)
				print("Global Path:", node.GlobalPath)
			end,
			icon = "icon16/application_osx_terminal.png"
		}
	},
	["function"] = {
		{
			name = "View source",
			func = function(ref, node, luaState)
				local useValue = isfunction(ref.value) and ref.value or ref.value.func
				if luaState == "Client" then
					local debugInfo = debug.getinfo(useValue, "S")
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
					if not string.EndsWith(ref.value.short_src, ".lua") then
						Derma_Message("Invalid function source: ".. ref.value.short_src.."\nOnly functions defined in Lua can be read!", "Function view source", "OK")
						return
					end

					net.Start("blobsProfiler:requestSource")
						net.WriteString(ref.value.short_src)
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
					local debugInfo = debug.getinfo(isfunction(ref.value) and ref.value or ref.value.func)
					propertiesData["debug.getinfo()"] = debugInfo
				elseif luaState == "Server" then
					local propertiesTbl = table.Copy(ref.value)
					propertiesTbl.fakeVarType = nil
					propertiesData["debug.getinfo()"] = propertiesTbl
				end
				
				local popupView = blobsProfiler.viewPropertiesPopup("View Function: " .. ref.key, propertiesData)
			end,
			icon = "icon16/magnifier.png"
		}
	}
}

blobsProfiler.Menu.TypeFolders = {}
blobsProfiler.Menu.TypeFolders.Client = {}
blobsProfiler.Menu.TypeFolders.Server = {}

for k,v in ipairs(blobsProfiler.Menu.GlobalTypesToCondense) do
	blobsProfiler.Menu.TypeFolders.Client[v.type] = true
	blobsProfiler.Menu.TypeFolders.Server[v.type] = true
end

local function nodeEntriesTableKeySort(a, b)
	local aIsTable = type(a.value) == 'table'
	local bIsTable = type(b.value) == 'table'
	if aIsTable && !bIsTable then
		return true
	elseif !aIsTable && bIsTable then
		return false
	else
		return tostring(a.key) < tostring(b.key) -- Just in case.. (It's here for a reason :))
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
	local visualDataType = dataType
	local iconOverride = nil

	local childNode

	local useParent = parentNode
	
	if istable(nodeValue) and nodeValue.fakeVarType then
		visualDataType = nodeValue.fakeVarType
	end

	if isRoot && varType == "Lua.Globals" then
		local dataType = type(nodeData.value)
		local specialFolderPanel = blobsProfiler.Menu.TypeFolders[luaState][visualDataType]
		if specialFolderPanel && type(specialFolderPanel) == "Panel" then
			useParent = specialFolderPanel
		end
	end

	if visualDataType == "table" then
		childNode = useParent:AddNode(nodeKey)
		childNode.Icon:SetImage(specialType && "icon16/folder_database.png" || "icon16/folder.png")

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

			local RCTable = blobsProfiler.GetRCFunctionsTable(varType)
			if RCTable and RCTable[dataType] then				
				for k,v in ipairs(RCTable[dataType]) do
					if v.condition and not v.condition(nodeData, childNode, luaState) then
						continue
					end

					if v.onLoad then v.onLoad(nodeData, childNode) end
				end
			end

			childNode.oldExpand(...)
		end

		if varType == "SQLite.Schema" then
			if nodeValue["ID"] or nodeValue["Default"] or nodeValue["Not NULL"] then -- TODO: Gotta be a better way to determine if this is a SQL table entry
				childNode.Label:SetText(nodeValue.Name)
			end
			if nodeValue["Primary Key"] then
				childNode.Icon:SetImage("icon16/table_key.png")
			end
		end
	else
		local nodeText = nodeKey
		if varType == "SQLite.Schema" then
			nodeText = nodeKey .. ": " .. tostring(nodeValue)
		elseif varType == "Files" then
			nodeText = nodeValue
		elseif varType == "Profiling.Targets" then
			nodeText = nodeValue.name or nodeKey
		end

		childNode = useParent:AddNode(nodeText)
		childNode.Icon:SetImage("icon16/".. (blobsProfiler.TypesToIcon[visualDataType] || "page_white_text") ..".png")

		childNode.DoClick = function()
			if isRoot && useParent == parentNode && varType == "Globals" then
				print("blobsProfiler: Non-foldered root for type: ".. type(nodeValue))
			end

			return true
		end

	end

	childNode.GlobalPath = childNode.GlobalPath || ""

	if not nodeData.special then
		if isRoot then
			childNode.GlobalPath = nodeKey
		else
			childNode.GlobalPath = parentNode.GlobalPath .. "." .. nodeKey
		end
	end

	varType = varType or "Lua.Globals"

	childNode.DoRightClick = function()
		childNode:InternalDoClick()

		local RCTable = blobsProfiler.GetRCFunctionsTable(varType)
		if RCTable and RCTable[visualDataType] then
			blobsProfiler.Menu.RCMenu = DermaMenu()
			local RCMenu = blobsProfiler.Menu.RCMenu
			
			for _, rcM in ipairs(RCTable[visualDataType]) do
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

	local RCTable = blobsProfiler.GetRCFunctionsTable(varType)
	if RCTable and RCTable[visualDataType] then				
		for k,v in ipairs(RCTable[visualDataType]) do
			if v.condition and not v.condition(nodeData, childNode, luaState) then
				continue
			end

			if v.onLoad then v.onLoad(nodeData, childNode) end
		end
	end

	if not isRoot then
		childNode.parentNode = parentNode
	end

	if visualDataType and visualDataType == "function" then
		childNode.FunctionRef = {name=nodeKey, func=nodeValue, path = childNode.GlobalPath, fakeVarType = "function"}
		childNode:SetForceShowExpander(true)
		
		if varType ~= "Profiling.Targets" then
			childNode:IsFunc() -- This is what swaps the expander for a dcheckbox if it's a function
		else
			childNode:SetForceShowExpander(false) -- No need to select already selected functions for profiling..
		end

		blobsProfiler[luaState].Profile = blobsProfiler[luaState].Profile or {}
		
		blobsProfiler[luaState].Profile.Raw = blobsProfiler[luaState].Profile.Raw or {}
		blobsProfiler[luaState].Profile.Called = blobsProfiler[luaState].Profile.Called or {}
		blobsProfiler[luaState].Profile.Results = blobsProfiler[luaState].Profile.Results or {}
		childNode.Expander.OnChange = function(s, isChecked)
			blobsProfiler[luaState].Profile[varType] = blobsProfiler[luaState].Profile[varType] or {}
			
			if isChecked then
				blobsProfiler[luaState].Profile[varType][tostring(nodeValue)] = childNode.FunctionRef
				blobsProfiler[luaState].Profile.Raw[tostring(nodeValue)] = true
				blobsProfiler[luaState].Profile.Called[tostring(nodeValue)] = blobsProfiler[luaState].Profile.Called[tostring(nodeValue)] or {}
				blobsProfiler[luaState].Profile.Results[tostring(nodeValue)] = blobsProfiler[luaState].Profile.Results[tostring(nodeValue)] or {}
			else
				blobsProfiler[luaState].Profile[varType][tostring(nodeValue)] = nil
				blobsProfiler[luaState].Profile.Raw[tostring(nodeValue)] = falses
				blobsProfiler[luaState].Profile.Called[tostring(nodeValue)] = blobsProfiler[luaState].Profile.Called[tostring(nodeValue)] or {}
				blobsProfiler[luaState].Profile.Results[tostring(nodeValue)] = blobsProfiler[luaState].Profile.Results[tostring(nodeValue)] or {}
			end
		end
	end

	childNode.DoClick = function() -- hacky asf
		-- Find the first available right click option and run the func method (or expand)
		if selectedNode and selectedNode == childNode then -- ay carumba
			if childNode.lastClicked and (CurTime() - childNode.lastClicked > 1) then
				selectedNode = childNode
				childNode.lastClicked = CurTime()
				return
			end

			local dataType = type(nodeValue)
			local visualDataType = dataType
			if istable(nodeValue) and nodeValue.fakeVarType then
				visualDataType = nodeValue.fakeVarType -- every day we stray further away from god
			end

			local RCTable = blobsProfiler.GetRCFunctionsTable(varType)
			if dataType == "table" and childNode.Expander and childNode.Expander.SetExpanded then
				childNode:SetExpanded(not childNode:GetExpanded())
			elseif RCTable and RCTable[visualDataType] then
				for _, rcM in ipairs(RCTable[visualDataType]) do
					if rcM.condition and not rcM.condition(nodeData, childNode, luaState) then
						continue
					end
	
					rcM.func(nodeData, childNode, luaState) -- this should be first one they have access to
					break
				end
			end

			selectedNode = nil
			childNode.lastClicked = nil
		else
			selectedNode = childNode
			childNode.lastClicked = CurTime()
		end
	end

	childNode.varType = varType

	if varType == "Profiling.Targets" and isRoot then
		local fullModuleName = nodeData.key

		local getModule = blobsProfiler.GetModule(fullModuleName)
		if getModule and getModule.Icon then
			childNode.Icon:SetImage(getModule.Icon)
		end
	end

	local tblOverrides = blobsProfiler.GetIconOverrides(varType)
	if tblOverrides and tblOverrides[dataType] then
		childNode.Icon:SetImage(tblOverrides[dataType])
	end

	return childNode
end

local function buildDTree(luaState, parentPanel, rvarType, dataTableOverride)
	local dTree = vgui.Create("BP_DTree", parentPanel)
	dTree:Dock(FILL)
	--dTree:SetVisible(false)
	blobsProfiler.Log(blobsProfiler.L_DEBUG, "buildDTree " .. luaState .. " " .. rvarType)
	local rootNodes = {}

	local subModuleSplit = string.Explode(".", rvarType)
	local varType = subModuleSplit[1]

	if #subModuleSplit > 1 then
		varType = subModuleSplit[2] -- ew
	end

	local dataTable
	
	if dataTableOverride then
		dataTable = dataTableOverride
	else
		dataTable = blobsProfiler.GetDataTableForRealm(luaState, rvarType) or {}
	end

	if rvarType == "Lua.Globals" then -- TODO: make this shit modular
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
			if blobsProfiler.Menu.TypeFolders[luaState][nodeData.special] == true then
				blobsProfiler.Menu.TypeFolders[luaState][nodeData.special] = addDTreeNode(dTree, nodeData, true, true, rvarType, luaState)
				blobsProfiler.Menu.TypeFolders[luaState][nodeData.special].nodeData = nodeData
			end
		end
	elseif rvarType == "SQLite.Schema" then
		if dataTable.Tables and dataTable.Indices then
			table.insert(rootNodes, {
				key = "Tables",
				value = blobsProfiler.TableSort.SQLTableColSort(dataTable.Tables)
			})
	
			table.insert(rootNodes, {
				key = "Indices",
				value = blobsProfiler.TableSort.KeyAlphabetical(dataTable.Indices)
			})
		end
	else
		for k, v in pairs(dataTable) do
			table.insert(rootNodes, {
				key = k,
				value = v
			})
		end
	end

	if rvarType ~= "SQLite.Schema" then -- ewww
		table.sort(rootNodes, nodeEntriesTableKeySort)
	end

	local rootNodesLen = #rootNodes

	for index, nodeData in ipairs(rootNodes) do
		addDTreeNode(dTree, nodeData, false, true, rvarType, luaState)

		if index == rootNodesLen then
			dTree:SetVisible(true)
		end
	end
end

if blobsProfiler.Menu.MenuFrame && IsValid(blobsProfiler.Menu.MenuFrame) then
	blobsProfiler.Menu.MenuFrame:Remove() -- kill on lua refresh
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
		blobsProfiler.Client = {}
		blobsProfiler.Server = {}

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
	blobsProfiler.Menu.TypeFolders.Client = {}
	blobsProfiler.Menu.TypeFolders.Server = {}
	for k,v in ipairs(blobsProfiler.Menu.GlobalTypesToCondense) do
		blobsProfiler.Menu.TypeFolders.Client[v.type] = true
		blobsProfiler.Menu.TypeFolders.Server[v.type] = true
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

	blobsProfiler.Menu.MenuFrame.OnRemove = function()
		killAllSourcePopups()
	end

	local tabMenu = vgui.Create( "DPropertySheet", blobsProfiler.Menu.MenuFrame)
	tabMenu:Dock( FILL )
	
	local tabClient = vgui.Create("DPropertySheet", tabMenu)
	tabMenu:AddSheet("Client", tabClient, "icon16/application.png")

	local tabServer = vgui.Create("DPropertySheet", tabMenu)
	tabMenu:AddSheet("Server", tabServer, "icon16/application_xp_terminal.png")

	local tabSettings = vgui.Create("DPropertySheet", tabMenu)
	tabMenu:AddSheet("Settings", tabSettings, "icon16/cog.png")

	local luaStates = {
		Client = tabClient,
		Server = tabServer
	}

	local orderedModules = {}
	for moduleName, moduleData in pairs(blobsProfiler.Modules) do
		table.insert(orderedModules, {name=moduleName, data=moduleData})
	end

	local function sortByLoadPriority(a, b)
		return (a.data.OrderPriority or 9999) < (b.data.OrderPriority or 9999)
	end

	table.sort(orderedModules, sortByLoadPriority)
	local firstSubModule = {}
	for luaState, statePanel in pairs(luaStates) do
		for loadOrderID, loadData in ipairs(orderedModules) do
			local moduleName = loadData.name
			local moduleData = loadData.data
			local usePanelType = moduleData.SubModules and "DPropertySheet" or "DPanel"
			
			blobsProfiler.Log(blobsProfiler.L_DEBUG, "Module panel setup for module: " .. moduleName .. " (".. luaState ..")")
			
			local moduleTab = vgui.Create(usePanelType, statePanel)
			local moduleSheet = statePanel:AddSheet( moduleName, moduleTab, moduleData.Icon )

			if luaState == "Client" and moduleData.UpdateRealmData and moduleData.PreloadClient then
				blobsProfiler.Log(blobsProfiler.L_DEBUG, "Preloading client data for module: ".. moduleName)
				moduleData.UpdateRealmData("Client")
			end
			if luaState == "Server" and moduleData.UpdateRealmData and moduleData.PreloadServer then
				blobsProfiler.Log(blobsProfiler.L_DEBUG, "Preloading server data for module: ".. moduleName)
				moduleData.UpdateRealmData("Server")
				moduleData.retrievingData = true
			end

			if moduleData.BuildPanel then
				moduleData.BuildPanel(luaState, moduleTab)
			end

			if moduleData.SubModules then
				local orderedSubModules = {}
				for subModuleName, subModuleData in pairs(moduleData.SubModules) do
					table.insert(orderedSubModules, {name=subModuleName, data=subModuleData})
				end
			
				table.sort(orderedSubModules, sortByLoadPriority)


				for subLoadOrderID, subLoadData in pairs(orderedSubModules) do
					local subModuleName = subLoadData.name
					local subModuleData = subLoadData.data

					if not firstSubModule[moduleName] then firstSubModule[moduleName] = {name=subModuleName, data=subModuleData} end 

					local subModuleTab = vgui.Create("DPanel", moduleTab)
					local subModuleSheet = moduleTab:AddSheet( subModuleName, subModuleTab, subModuleData.Icon )

					if luaState == "Client" and subModuleData.PreloadClient and subModuleData.UpdateRealmData then
						blobsProfiler.Log(blobsProfiler.L_DEBUG, "Preloading client data for ".. moduleName .." submodule: ".. subModuleName)
						subModuleData.UpdateRealmData("Client")
					end
					if luaState == "Server" and subModuleData.PreloadServer and subModuleData.UpdateRealmData then
						blobsProfiler.Log(blobsProfiler.L_DEBUG, "Preloading server data for ".. moduleName .." submodule: ".. subModuleName)
						subModuleData.UpdateRealmData("Server")
						subModuleData.retrievingData = true
					end

					if subModuleData.CustomPanel then
						subModuleData.CustomPanel(luaState, subModuleTab)
					end

					if subModuleData.BuildPanel then
						subModuleData.BuildPanel(luaState, subModuleTab)
					end
					if subModuleData.RefreshButton then
						local refreshButton = vgui.Create("DButton", subModuleTab)
						refreshButton:Dock(BOTTOM)
						refreshButton:SetText(subModuleData.RefreshButton)
						refreshButton.DoClick = function()
							subModuleData.UpdateRealmData(luaState)
							if luaState == "Server" then subModuleData.retrievingData = true end
							if luaState == "Client" and subModuleData.BuildPanel then
								subModuleData.BuildPanel(luaState, subModuleTab)
							end
						end
					end
					subModuleTab.PaintOver = function(s,w,h)
						if luaState == "Server" and subModuleData.retrievingData then
							surface.SetDrawColor(50,50,50,100)
							surface.DrawRect(0,0,w,h)
							draw.SimpleTextOutlined("Retrieving data..", "HudDefault", w/2, h/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0,0,0))
						
							local subModuleFullName = moduleName .. "." .. subModuleName
							if blobsProfiler.chunkModuleData[subModuleFullName] and blobsProfiler.chunkModuleData[subModuleFullName].receivedChunks then
								local recvChunks = #blobsProfiler.chunkModuleData[subModuleFullName].receivedChunks
								local totChunks = blobsProfiler.chunkModuleData[subModuleFullName].totalChunks
		
								if recChunks ~= totChunks then
									draw.SimpleTextOutlined(recvChunks.. "/" .. totChunks, "HudDefault", w/2, h/2+15, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0,0,0))
								end
							end
						end
					end

					if luaState == "Client" then
						subModuleData.ClientTab = subModuleTab
					elseif luaState == "Server" then
						subModuleData.ServerTab = subModuleTab
						local rawModuleName = moduleName .. "." .. subModuleName
						local subModuleTable, parentModuleTable = blobsProfiler.GetModule(rawModuleName)

						subModuleSheet.Tab.PaintOver = function(s,w,h)
							if parentModuleTable.childrenReceiving and parentModuleTable.childrenReceiving[rawModuleName] then
								local recvTbl = parentModuleTable.childrenReceiving[rawModuleName]
								local recvChunks = recvTbl.receivedChunks and #recvTbl.receivedChunks or 0
								local totChunks = recvTbl.totalChunks or 1
								local perc = recvChunks / totChunks

								local dynamicH = (moduleTab.GetActiveTab and moduleTab:GetActiveTab() == s) and h-7 or h -- this is SO dumb
								local startY = (moduleTab.GetActiveTab and moduleTab:GetActiveTab() == s) and 0 or 1

								draw.RoundedBoxEx(4, 0, startY, perc * w, dynamicH, Color(255,255,0,50), true, true)
							elseif subModuleTable.flashyUpdate then
								if (moduleTab.GetActiveTab and moduleTab:GetActiveTab() == s) then -- TODO: DPanel subModuleTabs will never stop flashing
									subModuleTable.flashyUpdate = nil
									return
								end

								local flashState = math.floor(CurTime() / 0.35) % 2 == 0

								if flashState then
									local dynamicH = (moduleTab.GetActiveTab and moduleTab:GetActiveTab() == s) and h-7 or h -- this is SO dumb
									local startY = (moduleTab.GetActiveTab and moduleTab:GetActiveTab() == s) and 0 or 1

									draw.RoundedBoxEx(4, 0, startY, w, dynamicH, Color(0,255,0,50), true, true)
								end
							elseif subModuleTable.retrievingData then
								local marqueeSpeed = 50  -- Speed of the marquee movement in pixels per second
								local marqueeWidth = 50  -- Width of the marquee rectangle
								local currentTime = CurTime()
							
								local marqueeX = (currentTime * marqueeSpeed) % (w + marqueeWidth) - marqueeWidth
							
								local dynamicH = (moduleTab.GetActiveTab and moduleTab:GetActiveTab() == s) and h-7 or h -- this is SO dumb
								local startY = (moduleTab.GetActiveTab and moduleTab:GetActiveTab() == s) and 0 or 1
							
								local visibleWidth = marqueeWidth
								local drawLeftRound = false
								local drawRightRound = false
							
								if marqueeX < 0 then -- off screen - left side
									visibleWidth = marqueeWidth + marqueeX
									marqueeX = 0
									drawLeftRound = true
								elseif marqueeX + marqueeWidth > w then -- off screen - right side
									visibleWidth = w - marqueeX
									drawRightRound = true
								end
							
								draw.RoundedBoxEx(
									4,
									marqueeX,
									startY,
									visibleWidth,
									dynamicH,
									Color(255, 255, 0, 50),
									drawLeftRound,  -- Top-left rounding if the left edge is offscreen
									drawRightRound  -- Top-right rounding if the right edge is offscreen
								)
							end
						end
					end
					moduleTab:OnActiveTabChanged(nil, moduleTab:GetActiveTab())
				end

				moduleTab.OnActiveTabChanged = function(s, pnlOld, pnlNew)
					local rawModuleName = moduleName .. "." .. pnlNew:GetText()
					local subModuleTable, parentModuleTable = blobsProfiler.GetModule(rawModuleName)

					if not blobsProfiler[luaState][moduleName] or not blobsProfiler[luaState][moduleName][pnlNew:GetText()] then
						if subModuleTable.UpdateRealmData then
							subModuleTable:UpdateRealmData(luaState)
							if luaState == "Server" then
								subModuleTable.retrievingData = true
							end
						end
					end

					if subModuleTable.OnOpen then
						local prntPanel
						if luaState == "Client" then
							prntPanel = subModuleTable.ClientTab
						elseif luaState == "Server" then
							prntPanel = subModuleTable.ServerTab
						end
						subModuleTable.OnOpen(luaState, prntPanel)
					end
				end
			end

			moduleTab.PaintOver = function(s,w,h)
				if luaState == "Server" and moduleData.retrievingData then
					surface.SetDrawColor(50,50,50,100)
					surface.DrawRect(0,0,w,h)
					draw.SimpleTextOutlined("Retrieving data..", "HudDefault", w/2, h/2-15, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0,0,0))
					
					if blobsProfiler.chunkModuleData[moduleName] and blobsProfiler.chunkModuleData[moduleName].receivedChunks then
						local recvChunks = #blobsProfiler.chunkModuleData[moduleName].receivedChunks
						local totChunks = blobsProfiler.chunkModuleData[moduleName].totalChunks

						if recChunks ~= totChunks then
							draw.SimpleTextOutlined(recvChunks.. "/" .. totChunks, "HudDefault", w/2, h/2+15, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0,0,0))
						end
					end
				end
			end

			if moduleData.RefreshButton then
				local refreshButton = vgui.Create("DButton", moduleTab)
				refreshButton:Dock(BOTTOM)
				refreshButton:SetText(moduleData.RefreshButton)
				refreshButton.DoClick = function()
					moduleData.UpdateRealmData(luaState)
					if luaState == "Server" then moduleData.retrievingData = true end
					if luaState == "Client" and moduleData.BuildPanel then
						moduleData.BuildPanel(luaState, moduleTab)
					end
				end
			end

			if luaState == "Client" then
				moduleData.ClientTab = moduleTab
			elseif luaState == "Server" then
				moduleData.ServerTab = moduleTab

				local moduleTable = blobsProfiler.GetModule(moduleName)
				moduleSheet.Tab.PaintOver = function(s,w,h)
					-- 'Total' indicator progress bar of all submodules progress
					if moduleTable.childrenReceiving then
						local totRecv = 0
						local totChunks = 1

						for moduleN, moduleRD in pairs(moduleTable.childrenReceiving) do
							totRecv = totRecv + (moduleRD.receivedChunks and #moduleRD.receivedChunks or 0)
							totChunks = totChunks + (moduleRD.totalChunks or 1)
						end

						local totalPerc = totRecv / totChunks

						local dynamicH = (statePanel.GetActiveTab and statePanel:GetActiveTab() == s) and h-7 or h -- this is SO dumb
						local startY = (statePanel.GetActiveTab and statePanel:GetActiveTab() == s) and 0 or 1
						draw.RoundedBoxEx(4, 0, startY, totalPerc * w, dynamicH, Color(255,255,0,50), true, true)
					elseif moduleTable.flashyUpdate then
						if (statePanel.GetActiveTab and statePanel:GetActiveTab() == s) then -- TODO: DPanel subModuleTabs will never stop flashing
							moduleTable.flashyUpdate = nil
							return
						end

						local flashState = math.floor(CurTime() / 0.35) % 2 == 0

						if flashState then
							local dynamicH = (statePanel.GetActiveTab and statePanel:GetActiveTab() == s) and h-7 or h -- this is SO dumb
							local startY = (statePanel.GetActiveTab and statePanel:GetActiveTab() == s) and 0 or 1
							draw.RoundedBoxEx(4, 0, startY, w, dynamicH, Color(0,255,0,50), true, true)
						end
					elseif moduleTable.retrievingData then
						local marqueeSpeed = 50  -- Speed of the marquee movement in pixels per second
						local marqueeWidth = 50  -- Width of the marquee rectangle
						local currentTime = CurTime()
					
						local marqueeX = (currentTime * marqueeSpeed) % (w + marqueeWidth) - marqueeWidth
					
						local dynamicH = (statePanel.GetActiveTab and statePanel:GetActiveTab() == s) and h-7 or h -- this is SO dumb
						local startY = (statePanel.GetActiveTab and statePanel:GetActiveTab() == s) and 0 or 1
					
						local visibleWidth = marqueeWidth
						local drawLeftRound = false
						local drawRightRound = false
					
						if marqueeX < 0 then
							visibleWidth = marqueeWidth + marqueeX
							marqueeX = 0
							drawLeftRound = true
						elseif marqueeX + marqueeWidth > w then
							visibleWidth = w - marqueeX
							drawRightRound = true
						end
					
						draw.RoundedBoxEx(
							4,
							marqueeX,
							startY,
							visibleWidth,
							dynamicH,
							Color(255, 255, 0, 50),
							drawLeftRound,  -- Top-left rounding if the left edge is offscreen
							drawRightRound  -- Top-right rounding if the right edge is offscreen
						)
					end
				end
			end
		end

		--[[
		local tabSQL = vgui.Create( "DPropertySheet", statePanel )
		statePanel:AddSheet( "SQLite", tabSQL, "icon16/database.png" )
		buildSQLTab(luaState, tabSQL)
		blobsProfiler.Tabs[luaState].SQLite = tabSQL]]
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

		if blobsProfiler.Modules[subActiveTab:GetText()] and firstSubModule[subActiveTab:GetText()] then
			if pnlNew:GetText() == "Server" and firstSubModule[subActiveTab:GetText()].data.UpdateRealmData then
				if blobsProfiler.Server[subActiveTab:GetText()][firstSubModule[subActiveTab:GetText()].name] then return end
				firstSubModule[subActiveTab:GetText()].data.retrievingData = true
				firstSubModule[subActiveTab:GetText()].data:UpdateRealmData(pnlNew:GetText())
			end
		end

		-- get selected module tab, call on ActiveTabChanged
		if pnlNew:GetText() == "Client" then
			tabClient:OnActiveTabChanged(nil, tabClient:GetActiveTab())
		else
			tabServer:OnActiveTabChanged(nil, tabServer:GetActiveTab())
		end
	end

	tabClient.OnActiveTabChanged = function(s, pnlOld, pnlNew)
		blobsProfiler.Menu.MenuFrame:SetTitle("blobsProfiler - " .. blobsProfiler.Menu.selectedRealm .. " - " .. pnlNew:GetText())
		local moduleTable = blobsProfiler.GetModule(pnlNew:GetText())

		if not blobsProfiler.Client[pnlNew:GetText()] then
			if moduleTable.UpdateRealmData then
				moduleTable:UpdateRealmData("Client")
			end
		end

		local getSheet = pnlNew:GetPanel()
		if getSheet.OnActiveTabChanged then
			getSheet:OnActiveTabChanged(nil, getSheet:GetActiveTab())
		end
	end

	tabServer.OnActiveTabChanged = function(s, pnlOld, pnlNew)
		blobsProfiler.Menu.MenuFrame:SetTitle("blobsProfiler - " .. blobsProfiler.Menu.selectedRealm .. " - " .. pnlNew:GetText())
		local moduleTable = blobsProfiler.GetModule(pnlNew:GetText())

		if not blobsProfiler.Server[pnlNew:GetText()] then
			if moduleTable.UpdateRealmData then
				moduleTable.retrievingData = true
				moduleTable:UpdateRealmData("Server")
			end
		end

		if firstSubModule[pnlNew:GetText()] then
			if firstSubModule[pnlNew:GetText()].data.UpdateRealmData then
				if blobsProfiler.Server[pnlNew:GetText()][firstSubModule[pnlNew:GetText()].name] then return end
				firstSubModule[pnlNew:GetText()].data.retrievingData = true
				firstSubModule[pnlNew:GetText()].data:UpdateRealmData("Server")
			end
		end

		local getSheet = pnlNew:GetPanel()
		if getSheet.OnActiveTabChanged then
			getSheet:OnActiveTabChanged(nil, getSheet:GetActiveTab())
		end
	end

	tabMenu:OnActiveTabChanged(nil, tabMenu:GetActiveTab()) -- lol
end)

local function handleSVDataUpdate(rawModuleName, dataTable)
	local moduleTable, parentModule = blobsProfiler.GetModule(rawModuleName)
	blobsProfiler.Log(blobsProfiler.L_DEBUG, "requestData module: ".. rawModuleName)

	if parentModule then
		if parentModule.childrenReceiving[rawModuleName] then
			parentModule.childrenReceiving[rawModuleName] = nil
		end

		parentModule.flashyUpdate = true
	else
		if moduleTable.childrenReceiving[rawModuleName] then
			moduleTable.childrenReceiving[rawModuleName] = nil
		end
	end

	blobsProfiler.SetRealmData("Server", rawModuleName, dataTable)
	moduleTable.retrievingData = false
	moduleTable.flashyUpdate = true

	if moduleTable.BuildPanel then
		moduleTable.BuildPanel("Server", moduleTable.ServerTab)
		blobsProfiler.Log(blobsProfiler.L_DEBUG, "Module.BuildPanel completed for ".. rawModuleName .. " (Server)")
	end
end

blobsProfiler.chunkModuleData = {}

net.Receive("blobsProfiler:requestData", function()
    local moduleName = net.ReadString()
    local totalChunks = net.ReadUInt(16)
    local currentChunk = net.ReadUInt(16)
    local chunkData = net.ReadData(blobsProfiler.svDataChunkSize)

	local moduleSplit = string.Explode(".", moduleName)
    local moduleParent = moduleSplit[1]

    if not blobsProfiler.chunkModuleData[moduleName] then
        blobsProfiler.chunkModuleData[moduleName] = {
            totalChunks = totalChunks,
            receivedChunks = {},
        }
    end

    if not blobsProfiler.chunkModuleData[moduleName].receivedChunks then
        blobsProfiler.chunkModuleData[moduleName].receivedChunks = {}
    end

    table.insert(blobsProfiler.chunkModuleData[moduleName].receivedChunks, chunkData)

	-- using blobsProfiler.Modules is acceptable here because it would look shit using .GetModule (i tried)
	blobsProfiler.Modules[moduleParent].childrenReceiving = blobsProfiler.Modules[moduleParent].childrenReceiving or {}
	blobsProfiler.Modules[moduleParent].childrenReceiving[moduleName] =  blobsProfiler.chunkModuleData[moduleName]

    if #blobsProfiler.chunkModuleData[moduleName].receivedChunks == totalChunks then
        local fullData = table.concat(blobsProfiler.chunkModuleData[moduleName].receivedChunks)
        blobsProfiler.chunkModuleData[moduleName] = util.JSONToTable(util.Decompress(fullData))

        handleSVDataUpdate(moduleName, blobsProfiler.chunkModuleData[moduleName])

		blobsProfiler.chunkModuleData[moduleName] = nil
		blobsProfiler.Modules[moduleParent].childrenReceiving[moduleName] = nil

		if table.Count(blobsProfiler.Modules[moduleParent].childrenReceiving) == 0 then
			blobsProfiler.Modules[moduleParent].childrenReceiving = nil
		end
    end
end)

blobsProfiler.buildDTree = buildDTree