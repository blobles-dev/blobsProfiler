if SERVER then
    util.AddNetworkString("blobsProfiler:sendLua")
end

blobsProfiler.RegisterModule("Lua", {
    Icon = "icon16/world.png",
    OrderPriority = 1,
})

local validTypes = {
    ["string"] = true,
    ["number"] = true,
    ["boolean"] = true,
    --["Panel"] = true, -- the function is only used for serverside, which this will never exist on anyway
    ["function"] = true,
    --["Entity"] = true,
    --["Vector"] = true,
    --["Angle"] = true,
    --["table"] = true,
    --["Weapon"] = true,
    --["Player"] = true
}

blobsProfiler.serialiseGlobals = function()
    local function copyTable(orig, seen)
        seen = seen or {}
        if seen[orig] then
            return seen[orig]
        end

        local copy = {}
        seen[orig] = copy

        for k, v in pairs(orig) do
            local keyIsValid = type(k) == "string" or type(k) == "number" or type(k) == "boolean"
            local value

            if validTypes[type(v)] and keyIsValid then
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
            else
                -- This line can get spammy
                -- pOn can only encode certain types, so we need to whitelist (for now)
                -- print("blobsProfiler.serialiseGlobals: Invalid type for key:", k, "value:", v, "type:", type(v))
            end
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
    --RefreshButton = "Re-scan" -- TODO: I couldn't get this to play nice, so I gave up for now
})

blobsProfiler.RegisterSubModule("Lua", "Execute", {
    Icon = "icon16/script_code.png",
    CustomPanel = function(luaState, parentPanel)
        local dhtmlPanel = blobsProfiler.generateAceEditorPanel(parentPanel)

        dhtmlPanel:Dock(FILL)

        dhtmlPanel:AddFunction("gmod", "receiveEditorContent", function(value)
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
    end
})

net.Receive("blobsProfiler:sendLua", function(l, ply)
    if not SERVER or not blobsProfiler.CanAccess(ply, "sendLua", "Server") then return end
    local luaRun = net.ReadString()

    blobsProfiler.Log(blobsProfiler.L_LOG, ply:Name() .. " (".. ply:SteamID64() ..") sent Lua to the server:")
    blobsProfiler.Log(blobsProfiler.L_LOG, luaRun)

    RunString(luaRun)
end)