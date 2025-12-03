local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")

local placeId = game.PlaceId  

local function reconnect()
    while true do
        task.wait(5)
        local success, err = pcall(function()
            TeleportService:Teleport(placeId)
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
end)



