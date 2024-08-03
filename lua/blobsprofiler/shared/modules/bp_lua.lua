if SERVER then
    util.AddNetworkString("blobsProfiler:sendLua")
    util.AddNetworkString("blobsProfiler:sendLua_versus")
end

blobsProfiler.RegisterModule("Lua", {
    Icon = "icon16/world.png",
    OrderPriority = 2,
})

--[[local validTypes = {
    ["string"] = true,
    ["number"] = true,
    ["boolean"] = true,
    --["Panel"] = true, -- the function is only used for serverside, which this will never exist on anyway
    ["function"] = true,
    ["Entity"] = true,
    ["Vector"] = true,
    ["Angle"] = true,
    ["table"] = true,
    ["Weapon"] = true,
    ["Player"] = true
}]]
-- https://gist.github.com/Yogpod/94b8ffa6ed9222e29961d0288f2b969c

blobsProfiler.serialiseGlobals = function()
    local function copyTable(orig, seen)
        seen = seen or {}
        if seen[orig] then
            return nil
            --return seen[orig]
        end

        local copy = {}
        seen[orig] = copy

        for k, v in pairs(orig) do
            --local keyIsValid = type(k) == "string" or type(k) == "number" or type(k) == "boolean"
            local value

            --if validTypes[type(v)] and keyIsValid then
                if type(v) == 'table' then
                    value = copyTable(v, seen)
                elseif type(v) == 'function' then
                    local getDebugInfo = debug.getinfo(v, "S")
                    value = {
                        func = tostring(v),
                        fakeVarType = "function",
                        lastlinedefined	= getDebugInfo.lastlinedefined,
                        linedefined	= getDebugInfo.linedefined,
                        short_src = getDebugInfo.short_src
                        --debugInfo = debugInfo -- this breaks pON??
                    }
                else
                    value = v
                end
                copy[k] = value
            --else
                -- This line can get spammy
                -- pOn can only encode certain types, so we need to whitelist (for now)
                -- print("blobsProfiler.serialiseGlobals: Invalid type for key:", k, "value:", v, "type:", type(v))
            --end
        end

        return copy
    end

    return copyTable(_G)
end

blobsProfiler.RegisterSubModule("Lua", "Globals", {
    Icon = "icon16/page_white_world.png",
    OrderPriority = 1,
    UpdateRealmData = function(luaState, t)
        if luaState == "Client" then
            blobsProfiler.Client.Lua = blobsProfiler.Client.Lua or {}
            local gimmyG = table.Copy(_G)
            blobsProfiler.Client.Lua.Globals = gimmyG
        else
            net.Start("blobsProfiler:requestData")
                net.WriteString("Lua.Globals")
            net.SendToServer()
        end
    end,
    PrepServerData = function()
        local _GSerialized = blobsProfiler.serialiseGlobals()
        return _GSerialized
    end,
    PreloadClient = true,
    PreloadServer = false,
    BuildPanel = function(luaState, parentPanel)
        blobsProfiler.Menu.TypeFolders = {}
        blobsProfiler.Menu.TypeFolders.Client = {}
        blobsProfiler.Menu.TypeFolders.Server = {}
        for k,v in ipairs(blobsProfiler.Menu.GlobalTypesToCondense) do
            blobsProfiler.Menu.TypeFolders.Client[v.type] = true
            blobsProfiler.Menu.TypeFolders.Server[v.type] = true
        end

		blobsProfiler.buildDTree(luaState, parentPanel, "Lua.Globals")
    end,
    RefreshButton = "Re-scan" -- TODO: I couldn't get this to play nice, so I gave up for now
})

local function luaExecuteFilesInit()
    if not file.Exists("blobsProfiler", "DATA") then
        file.CreateDir("blobsProfiler")
    end

    if not file.Exists("blobsProfiler/Client_LuaExecute.txt", "DATA") then
        file.Write("blobsProfiler/Client_LuaExecute.txt", [[print("Hello client!")]])
    end

    if not file.Exists("blobsProfiler/Server_LuaExecute.txt", "DATA") then
        file.Write("blobsProfiler/Server_LuaExecute.txt", [[print("Hello server!")]])
    end
end

if CLIENT then
    luaExecuteFilesInit()
end

blobsProfiler.RegisterSubModule("Lua", "Execute", {
    Icon = "icon16/script_code.png",
    OrderPriority = 2,
    CustomPanel = function(luaState, parentPanel)
        luaExecuteFilesInit()

        local preLoadContent = file.Read("blobsProfiler/"..luaState.."_LuaExecute.txt")
        local dhtmlPanel = blobsProfiler.generateAceEditorPanel(parentPanel, preLoadContent or [[print("Hello world!")]])

        dhtmlPanel:Dock(FILL)
        dhtmlPanel.lastCode = preLoadContent

        dhtmlPanel:AddFunction("gmod", "saveContentsToFile", function(value)
            if value ~= dhtmlPanel.lastCode then -- prevent unnecessary writes
                blobsProfiler.Log(blobsProfiler.L_DEBUG, "Writing Lua Execute editor content to: 'blobsProfiler/"..luaState.."_LuaExecute.txt'")
                file.Write("blobsProfiler/"..luaState.."_LuaExecute.txt", value)
                dhtmlPanel.lastCode = value
            end
        end)

        dhtmlPanel:AddFunction("gmod", "receiveEditorContent", function(value)
            if value ~= dhtmlPanel.lastCode then -- prevent unnecessary writes
                blobsProfiler.Log(blobsProfiler.L_DEBUG, "Writing Lua Execute editor content to: 'blobsProfiler/"..luaState.."_LuaExecute.txt'")
                file.Write("blobsProfiler/"..luaState.."_LuaExecute.txt", value)
                dhtmlPanel.lastCode = value
            end

            if luaState == "Client" then
                RunString(value)
            elseif luaState == "Server" then
                net.Start("blobsProfiler:sendLua")
                    net.WriteString(value) -- TODO: allow bigger strings? no biggy for now, needs to be done securely!
                net.SendToServer()
            end
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

        dhtmlPanel.attemptSaveContentsToFile = function()
            dhtmlPanel:RunJavascript([[
                var value = getEditorValue();
                gmod.saveContentsToFile(value);
            ]])
        end

        parentPanel.codePanel = dhtmlPanel
    end
})

timer.Create("blobsProfiler:LuaExecute_SaveToFile", 15, 0, function() -- TODO: Make this configurable once I do settings - and module settings
    local moduleTbl = blobsProfiler.GetModule("Lua.Execute")
    if not moduleTbl then return end

    if moduleTbl.ClientTab and moduleTbl.ClientTab.codePanel and moduleTbl.ClientTab.codePanel.attemptSaveContentsToFile then
        moduleTbl.ClientTab.codePanel.attemptSaveContentsToFile()
    end
    if moduleTbl.ServerTab and moduleTbl.ServerTab.codePanel and moduleTbl.ServerTab.codePanel.attemptSaveContentsToFile then
        moduleTbl.ServerTab.codePanel.attemptSaveContentsToFile()
    end
end)

local function prettyProfilerTimeFormat(seconds)
    if seconds >= 0.5 then
        return string.format("%.2fs", seconds)
    else
        return string.format("%.6fms", seconds * 1000)
    end
end

local function SetupResultsPanel(parentPanel, numIterations, lcTotalTime, lcMin, lcMax, rcTotalTime, rcMin, rcMax)
    parentPanel.stopCompare = false

    if parentPanel.resultsPanel and IsValid(parentPanel.resultsPanel) then
        parentPanel.resultsPanel:Remove()
        parentPanel.resultsPanel = nil
    end

    parentPanel.resultsPanel = vgui.Create("DPanel", parentPanel)
    parentPanel.resultsPanel:Dock(BOTTOM)
    parentPanel.resultsPanel:SetTall(70)

    local colorGreen = Color(0,136,0)
    local colorRed = Color(255,0,0)

    parentPanel.resultsPanel.Paint = function(s,w,h)
        draw.SimpleText("Total execution time: ".. prettyProfilerTimeFormat(lcTotalTime), "DermaDefault", 5, 5, lcTotalTime<rcTotalTime and colorGreen or colorRed, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Slowest execution time: ".. prettyProfilerTimeFormat(lcMax), "DermaDefault", 5, 20, lcMax<rcMax and colorGreen or colorRed, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Fastest execution time: ".. prettyProfilerTimeFormat(lcMin), "DermaDefault", 5, 35, lcMin<rcMin and colorGreen or colorRed, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Average execution time: ".. prettyProfilerTimeFormat((lcTotalTime/numIterations)), "DermaDefault", 5, 50, ((lcTotalTime/numIterations)<(rcTotalTime/numIterations)) and colorGreen or colorRed, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local dividerPos = parentPanel.codeContainer.m_DragBar:GetX()
        draw.SimpleText("Total execution time: ".. prettyProfilerTimeFormat(rcTotalTime), "DermaDefault", 5 + dividerPos, 5, lcTotalTime>rcTotalTime and colorGreen or colorRed, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Slowest execution time: ".. prettyProfilerTimeFormat(rcMax), "DermaDefault", 5 + dividerPos, 20, lcMax>rcMax and colorGreen or colorRed, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Fastest execution time: ".. prettyProfilerTimeFormat(rcMin), "DermaDefault", 5 + dividerPos, 35, lcMin>rcMin and colorGreen or colorRed, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Average execution time: ".. prettyProfilerTimeFormat((rcTotalTime/numIterations)), "DermaDefault", 5 + dividerPos, 50, ((lcTotalTime/numIterations)>(rcTotalTime/numIterations)) and colorGreen or colorRed, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end

blobsProfiler.RegisterSubModule("Lua", "Versus", {
    Icon = "icon16/application_cascade.png",
    CustomPanel = function(luaState, parentPanel)
        local leftCode = blobsProfiler.generateAceEditorPanel(parentPanel,[[local function addNumbers(a, b)
  return a + b
end

local sum = addNumbers(5, 5)]])
        local rightCode = blobsProfiler.generateAceEditorPanel(parentPanel,[[local sum = 5 + 5]])

        local codeContainer = vgui.Create("DHorizontalDivider", parentPanel)
        codeContainer:Dock(FILL)
        
        codeContainer:SetLeft(leftCode)
        codeContainer:SetRight(rightCode)
        
        codeContainer:SetLeftMin(0)
        codeContainer:SetRightMin(0)

        -- Custom paint function for the drag bar
        codeContainer.m_DragBar.Paint = function(s, w, h)
            surface.SetDrawColor(0, 0, 0)
            surface.DrawRect(0, 0, w, h)
        end
        
        local optionsContainer = vgui.Create("DPanel", parentPanel)
        optionsContainer:Dock(BOTTOM)
        optionsContainer:SetTall(50)

        local iterationNumSlider = vgui.Create("DNumSlider", optionsContainer)
        iterationNumSlider:SetText("## of iterations")
        iterationNumSlider.Label:SetTextColor(Color(0,0,0))
        iterationNumSlider:SetMin(0)
        iterationNumSlider:SetMax(50000)
        iterationNumSlider:SetDecimals(0)
        iterationNumSlider:SetValue(1000)
        iterationNumSlider:Dock(TOP)
        iterationNumSlider:DockMargin(15,0,0,0)
        iterationNumSlider:DockPadding(0,0,0,5)

        local runComparison = vgui.Create("DButton", optionsContainer)
        runComparison:Dock(BOTTOM)
        runComparison:SetText("Compare code")

        runComparison.DoClick = function()
            if not parentPanel.stopCompare or parentPanel.stopCompare == false then -- Is this redundant? probably. I forget. my brain is mush.
                if parentPanel.resultsPanel and IsValid(parentPanel.resultsPanel) then
                    parentPanel.resultsPanel:Remove()
                    parentPanel.resultsPanel = nil
                end

                leftCode:RunJavascript([[
                    var value = getEditorValue();
                    gmod.receiveEditorContent(value);
                ]])

                rightCode:RunJavascript([[
                    var value = getEditorValue();
                    gmod.receiveEditorContent(value);
                ]])

                parentPanel.stopCompare = true -- This will be reset when results are displayed
            else
                if runComparison.Warning and IsValid(runComparison.Warning) then runComparison.Warning:Remove() runComparison.Warning = nil end
                runComparison.Warning = Derma_Message("Please wait for the previous comparison to finish", "blobsProfiler - Slow down!", "OK")
            end
        end

        local leftCodeContent
        local rightCodeContent

        leftCode:AddFunction("gmod", "receiveEditorContent", function(value)
            leftCodeContent = value
        end)

        rightCode:AddFunction("gmod", "receiveEditorContent", function(value)
            rightCodeContent = value

            if luaState == "Client" then
                local numIterations = math.Round(iterationNumSlider:GetValue())
                if numIterations > 0 then
                    local lcMin, lcMax
                    local rcMin, rcMax -- Why aren't all these on a single line? because, fuck you. Thats why.
                    
                    -- TODO: Maybe add up the individual times, so the <l/c>c<Max/Min> checks aren't adding to performace (which is likely VERY minor)
                    local lcStart = SysTime()
                    for i=1, numIterations do
                        local ciStart = SysTime()
                        RunString(leftCodeContent)
                        local ciTotal = SysTime() - ciStart

                        if not lcMax or (ciTotal > lcMax) then lcMax = ciTotal end
                        if not lcMin or (ciTotal < lcMin) then lcMin = ciTotal end
                    end
                    local lcTotalTime = SysTime() - lcStart

                    local rcStart = SysTime()
                    for i=1, numIterations do
                        local ciStart = SysTime()
                        RunString(rightCodeContent)
                        local ciTotal = SysTime() - ciStart

                        if not rcMax or (ciTotal > rcMax) then rcMax = ciTotal end
                        if not rcMin or (ciTotal < rcMin) then rcMin = ciTotal end
                    end
                    local rcTotalTime = SysTime() - rcStart

                    SetupResultsPanel(parentPanel, numIterations, lcTotalTime, lcMin, lcMax, rcTotalTime, rcMin, rcMax)
                end
            elseif luaState == "Server" then
                blobsProfiler.Modules["Lua"].SubModules["Versus"].retrievingData = true
                net.Start("blobsProfiler:sendLua_versus")
                    net.WriteUInt(math.Round(iterationNumSlider:GetValue()) ,20)
                    net.WriteString(leftCodeContent)
                    net.WriteString(rightCodeContent)
                net.SendToServer()
            end
        end)

        parentPanel.codeContainer = codeContainer
    end,
    OnOpen = function(luaState, parentPanel)
        timer.Simple(0, function()
            local width = parentPanel.codeContainer:GetWide()
            local dividerWidth = parentPanel.codeContainer:GetDividerWidth() or 8
            local halfWidth = (width - dividerWidth) * 0.5
            parentPanel.codeContainer:SetLeftWidth(halfWidth)
        end)
    end
})

net.Receive("blobsProfiler:sendLua", function(l, ply)
    if not SERVER or not blobsProfiler.CanAccess(ply, "sendLua", "Server") then return end
    local luaRun = net.ReadString()

    blobsProfiler.Log(blobsProfiler.L_LOG, ply:Name() .. " (".. ply:SteamID64() ..") sent Lua to the server:")
    blobsProfiler.Log(blobsProfiler.L_LOG, luaRun)

    RunString(luaRun)
end)


net.Receive("blobsProfiler:sendLua_versus", function(l, ply)
    if not blobsProfiler.CanAccess(ply or LocalPlayer(), "sendLua_versus") then return end
    if SERVER then
        local numIterations = net.ReadUInt(20)
        local luaRunL = net.ReadString()
        local luaRunR = net.ReadString()

        if numIterations > 0 then
            local lcMin, lcMax
            local rcMin, rcMax -- Why aren't all these on a single line? because, fuck you. Thats why.
            
            -- TODO: Maybe add up the individual times, so the <l/c>c<Max/Min> checks aren't adding to performace (which is likely VERY minor)
            local lcStart = SysTime()
            for i=1, numIterations do
                local ciStart = SysTime()
                RunString(luaRunL)
                local ciTotal = SysTime() - ciStart

                if not lcMax or (ciTotal > lcMax) then lcMax = ciTotal end
                if not lcMin or (ciTotal < lcMin) then lcMin = ciTotal end
            end
            local lcTotalTime = SysTime() - lcStart

            local rcStart = SysTime()
            for i=1, numIterations do
                local ciStart = SysTime()
                RunString(luaRunR)
                local ciTotal = SysTime() - ciStart

                if not rcMax or (ciTotal > rcMax) then rcMax = ciTotal end
                if not rcMin or (ciTotal < rcMin) then rcMin = ciTotal end
            end
            local rcTotalTime = SysTime() - rcStart

            net.Start("blobsProfiler:sendLua_versus")
                net.WriteUInt(numIterations, 20)

                net.WriteDouble(lcTotalTime)
                net.WriteDouble(lcMin)
                net.WriteDouble(lcMax)

                net.WriteDouble(rcTotalTime)
                net.WriteDouble(rcMin)
                net.WriteDouble(rcMax)
            net.Send(ply)
        end
    else
        blobsProfiler.Modules["Lua"].SubModules["Versus"].retrievingData = false 
        
        local numIterations = net.ReadUInt(20)

        local lcTotalTime = net.ReadDouble()
        local lcMin = net.ReadDouble()
        local lcMax = net.ReadDouble()

        local rcTotalTime = net.ReadDouble()
        local rcMin = net.ReadDouble()
        local rcMax = net.ReadDouble()

        local parentPanel = blobsProfiler.Modules["Lua"].SubModules["Versus"].ServerTab
        SetupResultsPanel(parentPanel, numIterations, lcTotalTime, lcMin, lcMax, rcTotalTime, rcMin, rcMax)
    end
end)