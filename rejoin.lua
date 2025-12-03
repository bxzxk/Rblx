local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local placeId = game.PlaceId

local reconnecting = false
local retryDelay = 5

local function reconnect()
    if reconnecting then return end
    reconnecting = true

    warn("Reconnecting in " .. retryDelay .. " seconds...")
    task.wait(retryDelay)

    local success, result = pcall(function()
        TeleportService:Teleport(placeId, player)
    end)

    if success then
        warn("Reconnection attempt triggered!")
    else
        warn("Teleport failed, retrying... (" .. tostring(result) .. ")")
        reconnecting = false
        reconnect()
    end
end

-- Detect Roblox disconnect for shutdowns and kicks (gui method)
CoreGui.ChildAdded:Connect(function(child)
    if child.Name == "RobloxReconnect" or
       child.Name == "ErrorPrompt" or
       child:FindFirstChild("ErrorMessage") then
        reconnect()
    end
end)

-- failsafe to look for gui updates
CoreGui.DescendantAdded:Connect(function(desc)
    if desc.Name == "ErrorMessage" or desc.Name == "Reconnect" then
        reconnect()
    end
end)


-- uncomment this later if updated one doesnt work right

--[[ local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local placeId = game.PlaceId  

local function reconnect()
    while true do
        task.wait(5)
        local success, err = pcall(function()
            TeleportService:Teleport(placeId, player)
        end)

        if success then
            break
        else
            warn("Reconnect failed, retrying... (" .. tostring(err) .. ")")
        end
    end
end

GuiService.ErrorMessageChanged:Connect(function()
    task.wait(2)
    reconnect()
end) ]]--
