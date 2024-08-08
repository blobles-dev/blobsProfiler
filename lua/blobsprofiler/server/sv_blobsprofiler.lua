print("blobsProfiler - SV INIT")

util.AddNetworkString("blobsProfiler:requestSource")
util.AddNetworkString("blobsProfiler:sendSourceChunk")

util.AddNetworkString("blobsProfiler:requestData")

local function SendChunkedString(ply, requestID, largeString)
    local chunkSize = 30000  -- If changed, don't forget to change on the client!
    local totalLength = #largeString

    for i = 1, totalLength, chunkSize do
        local chunk = largeString:sub(i, i + chunkSize - 1)
        net.Start("blobsProfiler:sendSourceChunk")
        net.WriteString(requestID)
        net.WriteUInt(i, 32)
        net.WriteString(chunk)
        net.Send(ply)
    end
end

net.Receive("blobsProfiler:requestSource", function(l, ply)
    if not blobsProfiler.CanAccess(ply, "requestSource") then return end

    local filePath = net.ReadString()
    local startLine = net.ReadUInt(16)
    local endLine = net.ReadUInt(16)

    if startLine < 0 or endLine < 0 or startLine > endLine then return end

    local findFile = file.Open(filePath, "r", "GAME")
    if not findFile then
        blobsProfiler.Log(blobsProfiler.L_NH_ERROR, "Cannot find file: " .. filePath)
        return
    end

    local fileContent = {}
    local currentLine = 1
    local readWholeFile = (startLine == 0 and endLine == 0)

    if startLine == 0 then
        startLine = 1
    end

    while not findFile:EndOfFile() do
        local line = findFile:ReadLine()

        if readWholeFile or (currentLine >= startLine and currentLine <= endLine) then
            table.insert(fileContent, line)
        end

        if not readWholeFile and currentLine > endLine then
            break
        end

        currentLine = currentLine + 1
    end

    findFile:Close()

    local combinedSource = table.concat(fileContent)
    local requestID = string.format("View source: %s (Lines: %i-%i)", filePath, startLine, (endLine == 0 and currentLine) or endLine)  -- Generate request ID
    SendChunkedString(ply, requestID, combinedSource)
end)

local transmissionStates = {}

local function sendDataToClient(ply, moduleName, dataTbl)
    if transmissionStates[ply] and transmissionStates[ply][moduleName] then
        return
    end

    local data = util.Compress(util.TableToJSON(dataTbl))
    local totalChunks = math.ceil(#data / blobsProfiler.svDataChunkSize)

    transmissionStates[ply] = transmissionStates[ply] or {}
    transmissionStates[ply][moduleName] = {
        data = data,
        totalChunks = totalChunks,
        currentChunk = 1
    }

    local function sendNextChunk()
        if not IsValid(ply) then return end
        local state = transmissionStates[ply][moduleName]
        if not state then return end

        local startIdx = (state.currentChunk - 1) * blobsProfiler.svDataChunkSize + 1
        local endIdx = math.min(startIdx + blobsProfiler.svDataChunkSize - 1, #state.data)
        local chunk = string.sub(state.data, startIdx, endIdx)

        net.Start("blobsProfiler:requestData")
            net.WriteString(moduleName)
            net.WriteUInt(state.totalChunks, 16)
            net.WriteUInt(state.currentChunk, 16)
            net.WriteData(chunk, #chunk)
        net.Send(ply)

        state.currentChunk = state.currentChunk + 1
        if state.currentChunk > state.totalChunks then
            transmissionStates[ply][moduleName] = nil
        else
            timer.Simple(0.1, sendNextChunk)
        end
    end

    sendNextChunk()
end

local function transformModuleNameForPermissionsCheck(moduleName)
    -- Example: Takes 'Lua.Globals' and turns it into {'Lua', 'Lua_Globals'}
    local part1, part2 = string.match(moduleName, "([^%.]+)%.(.+)")
    
    if part1 and part2 then
        return { part1, part1 .. "_" .. part2 }
    else
        return { moduleName }
    end
end

blobsProfiler.SendModuleData = function(rawModuleName, ply)
    if not blobsProfiler.CanAccess(ply, "serverData") then return end
    blobsProfiler.Log(blobsProfiler.L_DEBUG, "requestData SV: ".. rawModuleName)

    local permStrs = transformModuleNameForPermissionsCheck(rawModuleName)
    for k, v in ipairs(permStrs) do
        if not blobsProfiler.CanAccess(ply, "serverData"..v) then return end -- Passing 'Lua.Globals' will check 'serverData_Lua' & 'serverData_Lua_Globals'
    end

    local moduleTable, parentModuleTable = blobsProfiler.GetModule(rawModuleName)

    local dataTbl

    if moduleTable and moduleTable.PrepServerData then
        dataTbl = moduleTable:PrepServerData()
        blobsProfiler.Log(blobsProfiler.L_DEBUG, "Module: ".. rawModuleName .. " PrepServerData() called!")
    end

    if not dataTbl then
        blobsProfiler.Log(blobsProfiler.L_NH_ERROR, "Module: ".. rawModuleName .." did not return data in PrepServerData()!")
        dataTbl = {}
    end

    sendDataToClient(ply, rawModuleName, dataTbl)
    blobsProfiler.Log(blobsProfiler.L_DEBUG, "Module: ".. rawModuleName .." data sent to client!")
end

net.Receive("blobsProfiler:requestData", function(l, ply)
    local rawModuleName = net.ReadString()

    blobsProfiler.SendModuleData(rawModuleName, ply)
end)