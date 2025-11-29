loadstring(game:HttpGet("https://raw.githubusercontent.com/bxzxk/Rblx/refs/heads/main/bsbossjumpbase.lua"))()

-- failsafe
task.delay(300, function()
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local placeId = game.PlaceId
    local cursor
    local foundServer = nil
    repeat
        local url = "https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Asc&limit=100"
        if cursor then
            url = url .. "&cursor=" .. cursor
        end
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        if success and result and result.data then
            for _, server in ipairs(result.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    foundServer = server
                    break
                end
            end
            cursor = result.nextPageCursor
        else
            break
        end
    until foundServer or not cursor
    if foundServer and LocalPlayer then
        TeleportService:TeleportToPlaceInstance(placeId, foundServer.id, LocalPlayer)
    else
        TeleportService:Teleport(placeId, LocalPlayer)
    end
end)
