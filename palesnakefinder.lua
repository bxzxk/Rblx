local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local reactFolder = playerGui:WaitForChild("react")

local networkFolder = ReplicatedStorage:WaitForChild("../out/acc/shared/network@eventDefinitions")
local rerollRemote = networkFolder:WaitForChild("dungeonResolveStandReroll")
local arrowRemote = networkFolder:WaitForChild("dungeonUseRequiemArrow")
local settingsRemote = networkFolder:WaitForChild("setSetting")

local function scanStandNames(standReroll, screenCenter)
    local leftElements = {}
    local rightElements = {}
    
    local exclusions = {"current", "new", "dmg", "hp", "party", "cap", "arrow", "rarity", "multiplier", "strongest", "take new", "keep current", "100%", "80%"}
    local rarities = {"basic", "gold", "rainbow", "secret", "rare", "epic", "legendary", "mythic", "common", "uncommon", "unusual", "shiny"}

    for _, element in pairs(standReroll:GetDescendants()) do
        if element:IsA("TextLabel") or element:IsA("TextButton") then
            local text = element.Text
            local textLower = string.lower(text)
            
            local isJunk = false
            if #text == 0 or #text > 25 then
                isJunk = true -- Filters out empty spaces and long paragraph descriptions
            else
                for _, word in ipairs(exclusions) do
                    if string.find(textLower, word) then isJunk = true break end
                end
                for _, word in ipairs(rarities) do
                    if textLower == word then isJunk = true break end
                end
            end
            
            if not isJunk then
                if element.AbsolutePosition.X < screenCenter then
                    table.insert(leftElements, element)
                else
                    table.insert(rightElements, element)
                end
            end
        end
    end
    
    table.sort(leftElements, function(a, b) return a.AbsolutePosition.Y < b.AbsolutePosition.Y end)
    table.sort(rightElements, function(a, b) return a.AbsolutePosition.Y < b.AbsolutePosition.Y end)
    
    local currentName = leftElements[1] and leftElements[1].Text or "Unknown"
    local newName = rightElements[1] and rightElements[1].Text or "Unknown"
    
    return currentName, newName
end

print("Pale Snake Finder started - Bozak")

-- MAIN TIMER LOOP
while true do
    print("Arrow used 30 seconds")
    task.wait(25)
    
    print("hiding battle, 5 seconds")
    settingsRemote:FireServer("show_battles", false)
    
    task.wait(5)
    
    print("Using Arrow")
    arrowRemote:FireServer()
    
    task.wait(1.5)
    
    local standReroll = reactFolder:FindFirstChild("standReroll")
    if standReroll and standReroll.Enabled then
        local screenCenter = standReroll.AbsoluteSize.X / 2
        
        local currentStand, rolledStand = scanStandNames(standReroll, screenCenter)
        
        print("----------------------------------------")
        print("[ROLL LOG] Current Stand: " .. currentStand)
        print("[ROLL LOG] Rolled Stand:  " .. rolledStand)
        print("----------------------------------------")
        
        if string.find(string.lower(currentStand), "pale snake") then
            print("Pale Snake found as current, Terminating.")
            rerollRemote:FireServer(false)
            break
            
        elseif string.find(string.lower(rolledStand), "pale snake") then
            print("Pale Snake found, Terminating.")
            rerollRemote:FireServer(true)
            break
            
        else
            print("Pale Snake not found, Continuing.")
            rerollRemote:FireServer(false)
        end
    else
        print("Arrow Used, Stand Menu not found, Continuing.")
    end
end

print("Terminated")
