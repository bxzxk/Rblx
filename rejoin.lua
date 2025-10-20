local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")

-- Automatically grab the place you're currently in
local placeId = game.PlaceId  

-- Function to try reconnecting until successful
local function reconnect()
    while true do
        -- small delay so it doesn’t spam requests
        task.wait(15)

        -- try teleporting back
        local success, err = pcall(function()
            TeleportService:Teleport(placeId)
        end)

        if success then
            break -- stop once we reconnect successfully
        else
            warn("Reconnect failed, retrying... (" .. tostring(err) .. ")")
        end
    end
end

-- Trigger when error/disconnect occurs
GuiService.ErrorMessageChanged:Connect(function()
    task.wait(2)
    reconnect()
end)

