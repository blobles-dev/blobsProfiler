print("blobsProfiler - SV INIT")

util.AddNetworkString("blobsProfiler:requestSource")
util.AddNetworkString("blobsProfiler:sendSourceChunk")

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
    local requestID = filePath .. startLine .. ":" .. endLine  -- Generate request ID
    SendChunkedString(ply, requestID, combinedSource)
end)