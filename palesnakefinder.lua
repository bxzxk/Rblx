local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local reactFolder = playerGui:WaitForChild("react")

local networkFolder = ReplicatedStorage:WaitForChild("../out/acc/shared/network@eventDefinitions")
local rerollRemote = networkFolder:WaitForChild("dungeonResolveStandReroll")
local arrowRemote = networkFolder:WaitForChild("dungeonUseRequiemArrow")

local function scanStandNames(standReroll, screenCenter)
    local leftElements = {}
    local rightElements = {}
    
    local exclusions = {"current", "new", "dmg", "hp", "party", "cap", "arrow", "rarity", "multiplier", "strongest", "take new", "keep current", "100%", "80%"}
    local rarities = {"basic", "gold", "rainbow", "secret"}

    for _, element in pairs(standReroll:GetDescendants()) do
        if element:IsA("TextLabel") or element:IsA("TextButton") then
            local text = element.Text
            local textLower = string.lower(text)
            
            local isJunk = false
            if #text == 0 or #text > 25 then
                isJunk = true
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

print("Loop On")

-- main loop
while true do
    print("Arrow Used waiting 30 secs")
    task.wait(20)
    print("10 seconds left")
    task.wait(5)
    print("5 seconds")
    task.wait(5)

    print("using arrow")
    arrowRemote:FireServer()
    
    task.wait(1.5)
    
    local standReroll = reactFolder:FindFirstChild("standReroll")
    if standReroll and standReroll.Enabled then
        local screenCenter = standReroll.AbsoluteSize.X / 2
        
        -- Scrape the actual text names from the screen layout
        local currentStand, rolledStand = scanStandNames(standReroll, screenCenter)
        
        -- ALWAYS log the names to the console, no matter what they are
        print("----------------------------------------")
        print("[ROLL LOG] Current Stand: " .. currentStand)
        print("[ROLL LOG] Rolled Stand:  " .. rolledStand)
        print("----------------------------------------")
        
        -- SMART EVALUATION LOGIC
        if string.find(string.lower(currentStand), "pale snake") then
            print("Pale Snake found as current, Terminating")
            rerollRemote:FireServer(false) -- Keep current
            break
            
        elseif string.find(string.lower(rolledStand), "pale snake") then
            print("Pale Snake found, Terminating")
            rerollRemote:FireServer(true) -- Take new!
            break
            
        else
            print("Pale Snake not found, Continuing")
            rerollRemote:FireServer(false) -- Keep old (rejects the roll)
        end
    else
        print("Arrow Used, gameUi standReroll not found")
    end
end

print("Terminated")