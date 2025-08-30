-- Load Check
loadstring(game:HttpGet("https://pastefy.app/s4oC5HgR/raw"))()
-- Lib Load
local library = loadstring(game:HttpGet("https://pastefy.app/gUEb2jc7/raw"))()

-- =========================
--  Bozak
-- =========================

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local StarterGui   = game:GetService("StarterGui")
local UIS          = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")
local LP           = Players.LocalPlayer

local haveFS = (typeof(isfile)=="function" and typeof(writefile)=="function"
    and typeof(readfile)=="function" and typeof(makefolder)=="function" and typeof(isfolder)=="function")

local CONFIG_DIR  = "BozakContainerRNG"
local CONFIG_PATH = CONFIG_DIR .. "/config.json"
if haveFS then
    pcall(function()
        if not isfolder(CONFIG_DIR) then makefolder(CONFIG_DIR) end
    end)
end

local Config = {
    selectedContainer  = "Junk",
    autoBuyContainer   = false,
    autoFarmContainers = false,
    autoCollectItems   = false,
    autoSellItems      = false,
    tweeningSpeed      = 30,
    uiVisible          = true,
    webhookEnabled     = true,
    hourlyEnabled      = true,
    webhookURL         = ""
}

local function readConfigFile()
    if not haveFS or not isfile(CONFIG_PATH) then return nil end
    local ok, txt = pcall(function() return readfile(CONFIG_PATH) end)
    if not ok or not txt or txt == "" then return nil end
    local ok2, tbl = pcall(function() return HttpService:JSONDecode(txt) end)
    if ok2 and type(tbl)=="table" then return tbl end
    return nil
end

local function loadConfig()
    if not haveFS then return end
    local existing = readConfigFile()
    if not existing then
        -- write an initial file with current defaults (no destructive merge)
        local ok, json = pcall(function() return HttpService:JSONEncode(Config) end)
        if ok then pcall(function() writefile(CONFIG_PATH, json) end) end
        return
    end
    for k, v in pairs(existing) do
        Config[k] = v
    end
end

-- merge-save that preserves a non-empty webhookURL already on disk
local saveQueued = false
local function saveConfig()
    if not haveFS then return end
    if saveQueued then return end
    saveQueued = true
    task.defer(function()
        local disk = readConfigFile() or {}
        local out = {}
        for k, v in pairs(Config) do
            if k == "webhookURL" then
                out[k] = (v and v ~= "") and v or (disk.webhookURL or "")
            else
                out[k] = v
            end
        end
        -- also carry forward any unknown keys from disk (future-proof)
        for k, v in pairs(disk) do
            if out[k] == nil then out[k] = v end
        end
        local ok, json = pcall(function() return HttpService:JSONEncode(out) end)
        if ok then pcall(function() writefile(CONFIG_PATH, json) end) end
        saveQueued = false
    end)
end

loadConfig()

local selectedContainer  = Config.selectedContainer
local autoBuyContainer   = Config.autoBuyContainer
local autoFarmContainers = Config.autoFarmContainers
local autoCollectItems   = Config.autoCollectItems
local autoSellItems      = Config.autoSellItems
local tweeningSpeed      = tonumber(Config.tweeningSpeed) or 30

local localPlot, itemCache
local isTweening   = false
local inventoryFull= false

local http_post_json
local avatarUrl

local function getWorldPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Attachment") then return inst.WorldPosition end
    if inst:IsA("Model") then
        local p = inst.PrimaryPart
        if p then return p.Position end
        local cf = inst:GetPivot()
        return cf and cf.Position or nil
    end
    local p = inst:FindFirstAncestorWhichIsA("BasePart")
    return p and p.Position or nil
end
local function waitUntil(fn, timeout)
    local t0, lim = os.clock(), (timeout or 8)
    while not fn() do
        if os.clock() - t0 > lim then return false end
        task.wait(0.15)
    end
    return true
end

-- resilient PlotLogic finder
local function getPlotLogic()
    if not localPlot then return nil end
    local direct = localPlot:FindFirstChild("PlotLogic")
    if direct then return direct end
    for _,d in ipairs(localPlot:GetChildren()) do
        if d:IsA("Folder") and d:FindFirstChild("ContainerHolder") then
            return d
        end
    end
    for _,d in ipairs(localPlot:GetDescendants()) do
        if d:IsA("Folder") then
            local ok = d:FindFirstChild("ContainerHolder") or d:FindFirstChild("ComputerSystem") or d:FindFirstChild("ContainerSlots")
            if ok then return d end
        end
    end
    return nil
end

local function ensureRefs()
    if (not localPlot) or (not localPlot.Parent) then
        local gameplay = workspace:FindFirstChild("Gameplay")
        local plots = gameplay and gameplay:FindFirstChild("Plots")
        if plots then
            for _, slot in ipairs(plots:GetChildren()) do
                local owned = false
                local okName, txt = pcall(function()
                    return slot.PlotLogic.PlotNameSign.PlayerInfoSign.PlayerNameSign.MainFrame.NameLabel.Text
                end)
                if okName and txt == (LP.Name .. "'s Market") then
                    owned = true
                else
                    for _, d in ipairs(slot:GetDescendants()) do
                        if d:IsA("ObjectValue") and (d.Name:lower():find("owner") or d.Name:lower():find("plotowner")) then
                            if d.Value == LP then owned = true; break end
                        elseif d:IsA("StringValue") and (d.Name:lower():find("owner") or d.Name:lower():find("player")) then
                            if d.Value == LP.Name then owned = true; break end
                        end
                    end
                end
                if owned then localPlot = slot; break end
            end
        end
    end
    local pl = getPlotLogic()
    itemCache = pl and pl:FindFirstChild("ItemCache") or nil
    return localPlot ~= nil and pl ~= nil
end

local function parseShortMoney(s)
    s = tostring(s or "0")
    s = s:gsub("[%$,]", ""):gsub("%s+", "")
    local suf = s:match("([KkMmBbTtQq])$")
    local mult = 1
    if suf then
        if suf=="K" or suf=="k" then mult=1e3
        elseif suf=="M" or suf=="m" then mult=1e6
        elseif suf=="B" or suf=="b" then mult=1e9
        elseif suf=="T" or suf=="t" then mult=1e12
        elseif suf=="Q" or suf=="q" then mult=1e15 end
        s = s:sub(1, #s-1)
    end
    local cleaned, dot = {}, false
    for i=1,#s do
        local ch = s:sub(i,i)
        if ch:match("%d") then table.insert(cleaned, ch)
        elseif ch=="." and not dot then dot=true; table.insert(cleaned, ".")
        elseif ch=="-" and i==1 then table.insert(cleaned, "-") end
    end
    local n = tonumber(table.concat(cleaned)) or 0
    return math.floor(n * mult + 0.5)
end
local function getCurrentMoney()
    local ok, text = pcall(function()
        return LP.PlayerGui.CurrencyUI.MainFrame.StatsFrame.Money.Amount.Text
    end)
    return parseShortMoney(ok and text or "0")
end
local function commify(n)
    local s = tostring(math.floor(n or 0))
    local neg = s:sub(1,1)=="-"; if neg then s=s:sub(2) end
    s = s:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
    return (neg and "-" or "") .. s
end

local function tween(position)
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return "no root" end
    isTweening = true
    local dist = (root.Position - position).Magnitude
    local speed = math.max(5, tweeningSpeed)
    local tw = TweenService:Create(
        root,
        TweenInfo.new(dist / speed, Enum.EasingStyle.Linear),
        { CFrame = CFrame.new(position, position + root.CFrame.LookVector) }
    )
    tw:Play()
    tw.Completed:Wait()
    isTweening = false
    local c = LP.Character
    if not c or not c:FindFirstChild("HumanoidRootPart") then return "no root" end
    return "success"
end

local function sell()
    if not autoSellItems then return false end
    local g = LP:FindFirstChild("PlayerGui")
    local notif = g and g:FindFirstChild("ScreenGui")
    notif = notif and notif:FindFirstChild("NotificationFrame")
    notif = notif and notif:FindFirstChild("Notification")
    local lbl = notif and notif:FindFirstChild("NotificationText")
    if not (lbl and lbl:IsA("TextLabel") and lbl.Text:find("INVENTORY IS FULL")) then
        return false
    end

    inventoryFull = true
    local house = localPlot.PlotDecor and localPlot.PlotDecor.House and localPlot.PlotDecor.House:FindFirstChild("Part")
    local p = getWorldPos(house) or (localPlot:GetPivot() and localPlot:GetPivot().Position + Vector3.new(0,5,0))
    if not p then return "no root" end
    if tween(p + Vector3.new(0,5,0)) == "no root" then return "no root" end

    pcall(function()
        firesignal(LP.PlayerGui.BackpackGui.Backpack.Hotbar.DropAll.MouseButton1Click)
    end)
    task.wait(1.5)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "Sold", Text = "Your items were dropped/sold", Duration = 10 })
    end)
    inventoryFull = false
    return true
end

local function snapshotGUIs()
    local set = {}
    for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if g:IsA("ScreenGui") then set[g] = true end
    end
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        for _, g in ipairs(pg:GetChildren()) do
            if g:IsA("ScreenGui") then set[g] = true end
        end
    end
    return set
end

local beforeSet = snapshotGUIs()

local window = library.Window()
local autofarmTab = window.Tab("Autofarm")

local autoBuySection = autofarmTab.Section("Auto Buy")
autoBuySection.Toggle("Auto Buy Container", function(on)
    autoBuyContainer = on; Config.autoBuyContainer = on; saveConfig()
end, autoBuyContainer)

local autoContainerSection = autofarmTab.Section("Auto Container")
autoContainerSection.Toggle("Auto Farm Container", function(on)
    autoFarmContainers = on; Config.autoFarmContainers = on; saveConfig()
end, autoFarmContainers)
autoContainerSection.Toggle("Pick Up Items", function(on)
    autoCollectItems = on; Config.autoCollectItems = on; saveConfig()
end, autoCollectItems)
autoContainerSection.Toggle("Sell Picked Up Items", function(on)
    autoSellItems = on; Config.autoSellItems = on; saveConfig()
end, autoSellItems)

local autofarmSettingsSection = autofarmTab.Section("Select")
local settingsTab = window.Tab("Settings")
local settingsSection = settingsTab.Section("Settings")
settingsSection.Slider("Farming Speed", 10, 120, tweeningSpeed, function(v)
    tweeningSpeed = v; Config.tweeningSpeed = v; saveConfig()
end)

local webhookSection = settingsTab.Section("Webhook")
if type(webhookSection.Toggle)=="function" then
    webhookSection.Toggle("Enable Webhook", function(on)
        Config.webhookEnabled = on; saveConfig()
    end, Config.webhookEnabled)
    webhookSection.Toggle("Send Hourly", function(on)
        Config.hourlyEnabled = on; saveConfig()
    end, Config.hourlyEnabled)
end
if type(webhookSection.Textbox)=="function" then
    webhookSection.Textbox("Discord Webhook URL", Config.webhookURL or "", function(text)
        Config.webhookURL = text or ""; saveConfig()
    end)
end
if type(webhookSection.Button)=="function" then
    webhookSection.Button("Test Webhook (Set Webhook in Config File)", function()
        if (Config.webhookURL or "") == "" then return end
        local payload = {
            username   = LP.Name,
            avatar_url = avatarUrl(),
            embeds = {{
                title = "Bozak's Container RNG — Test",
                description = "Your webhook is working!",
                color = 0x00FF00,
                footer = { text = "Bozak's ContainerRNG" }
            }}
        }
        http_post_json(Config.webhookURL, payload)
    end)
end

local containerMeta = {
    Junk=100,Scratched=200,Sealed=700,
    Military=3000,Metal=10000,Frozen=25000,
    Lava=50000,Corrupted=100000,Stormed=250000,
    Lightning=500000,Infernal=750000,
    Mystic=1500000,Glitched=5000000,
    Astral=10000000,Dream=25000000,
    Celestial=50000000,Fire=100000000,
    Golden=250000000,Diamond=500000000,
    Emerald=2500000000,Ruby=10000000000,
    Sapphire=75000000000,Space=150000000000,
    ["Deep Space"]=500000000000,Vortex=1000000000000,["Black Hole"]=2500000000000,
    Camo=5000000000000
}
local names = {}
for k in pairs(containerMeta) do table.insert(names, k) end
table.sort(names)
autofarmSettingsSection.Dropdown("Container Name", names, selectedContainer, function(v)
    selectedContainer = v; Config.selectedContainer = v; saveConfig()
end)

local afterSet = (function()
    local now = {}
    for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if g:IsA("ScreenGui") then now[g] = true end
    end
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        for _, g in ipairs(pg:GetChildren()) do
            if g:IsA("ScreenGui") then now[g] = true end
        end
    end
    return now
end)()

local managedGUIs = {}
for gui,_ in pairs(afterSet) do
    if not beforeSet[gui] then table.insert(managedGUIs, gui) end
end

local uiVisible = (Config.uiVisible ~= false)
local hasWindowAPI = (type(window.GetVisible)=="function" and type(window.SetVisible)=="function")
if hasWindowAPI then window:SetVisible(uiVisible)
else for _, gui in ipairs(managedGUIs) do if gui and gui.Parent then gui.Enabled = uiVisible end end end

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        uiVisible = not uiVisible
        Config.uiVisible = uiVisible
        saveConfig()
        if hasWindowAPI then window:SetVisible(uiVisible)
        else for _, gui in ipairs(managedGUIs) do if gui and gui.Parent then gui.Enabled = uiVisible end end end
    end
end)

http_post_json = function(url, bodyTable)
    if type(url)~="string" or url=="" then return false end
    local ok, bodyStr = pcall(function() return HttpService:JSONEncode(bodyTable) end)
    if not ok then return false end
    local req = syn and syn.request or (http and http.request) or http_request or request
    if req then
        local resp = req({Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=bodyStr})
        return resp and (resp.StatusCode>=200 and resp.StatusCode<300)
    else
        local ok2 = pcall(function()
            HttpService:PostAsync(url, bodyStr, Enum.HttpContentType.ApplicationJson)
        end)
        return ok2
    end
end
avatarUrl = function()
    return ("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png"):format(LP.UserId)
end
local lastHourMoney = getCurrentMoney()

local function sendHourlyWebhook()
    if not (Config.webhookEnabled and Config.hourlyEnabled) then return end
    if (Config.webhookURL or "") == "" then return end
    local nowMoney = getCurrentMoney()
    local delta    = nowMoney - (lastHourMoney or nowMoney)
    lastHourMoney  = nowMoney
    local payload = {
        username   = LP.Name,
        avatar_url = avatarUrl(),
        embeds = {{
            title = "Container RNG — Hourly Report",
            description = ("💰 **Current Money:** $%s\n⏱️ **Net Profit (last hour):** $%s")
                :format(commify(nowMoney), commify(delta)),
            color = 0x00B2FF,
            timestamp = DateTime.now():ToIsoDate(),
            footer = { text = "Bozak Auto Reporter" }
        }}
    }
    http_post_json(Config.webhookURL, payload)
end

-- send one report on load so you can confirm webhook is working
task.defer(function()
    task.wait(1)
    pcall(sendHourlyWebhook)
end)

task.spawn(function()
    while true do
        for _=1,3600 do task.wait(1) end
        pcall(sendHourlyWebhook)
    end
end)
task.spawn(function()
    while true do task.wait(20) saveConfig() end
end)

local function homePos()
    if not ensureRefs() then return nil end
    local ok, cf = pcall(function() return localPlot:GetPivot() end)
    return ok and cf and (cf.Position + Vector3.new(0,6,0)) or nil
end
local function forceUnstick()
    local char = Players.LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.Sit=false; hum.PlatformStand=false; hum:ChangeState(Enum.HumanoidStateType.GettingUp); hum.Jump=true end
    isTweening = false
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local home = homePos()
    if hrp and home then
        hrp.CFrame = CFrame.new(home)
        hrp.AssemblyLinearVelocity = Vector3.new()
    end
end
task.spawn(function()
    local last, still = nil, 0
    while true do
        task.wait(0.25)
        local char = Players.LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then forceUnstick(); continue end
        local p = hrp.Position
        if last then
            if (p-last).Magnitude < 0.15 and (autoFarmContainers or autoBuyContainer) then
                still += 0.25
                if still > 4 then
                    forceUnstick()
                    local hp = homePos()
                    if hp then tween(hp) end
                    still = 0
                end
            else
                still = 0
            end
        end
        last = p
    end
end)

task.spawn(function()
    ensureRefs()
    local pl0 = getPlotLogic()
    itemCache = pl0 and pl0:FindFirstChild("ItemCache") or nil

    repeat
        pcall(function()
            local sp = LP.PlayerGui.MenusUI:FindFirstChild("StarterPack")
            if sp and sp:FindFirstChild("CloseButton") then
                firesignal(sp.CloseButton.MouseButton1Click)
            end
        end)

        if not ensureRefs() then task.wait(0.2); continue end
        local plotLogic = getPlotLogic()
        if not plotLogic then task.wait(0.2); continue end
        local holderFolder = plotLogic:FindFirstChild("ContainerHolder")

        if holderFolder and #holderFolder:GetChildren() ~= 0 then
            if autoFarmContainers and not inventoryFull then
                for idx, model in ipairs(holderFolder:GetChildren()) do
                    if not model or not model.Parent then continue end

                    local logic  = model:FindFirstChild("ContainerLogic")
                    local holder = logic and logic:FindFirstChild("DoorProximityHolder")
                    local prompt = holder and (holder:FindFirstChildOfClass("ProximityPrompt")
                                    or holder:FindFirstChildWhichIsA("ProximityPrompt", true))

                    if holder and not prompt then
                        if itemCache then
                            for _, item in ipairs(itemCache:GetChildren()) do
                                local primary = item:FindFirstChild("PrimaryPart")
                                if not primary then continue end
                                local itemPos = primary.Position

                                local contPos = getWorldPos(model:FindFirstChild("Container")) or getWorldPos(model)
                                if not contPos then continue end

                                local ok, cf, size = pcall(function() local a,b=model:GetBoundingBox(); return a,b end)
                                if not ok or not cf or not size then continue end
                                local rel = cf:PointToObjectSpace(itemPos)
                                local half = size * 0.5
                                local planar = ((itemPos * Vector3.new(1,0,1)) - (contPos * Vector3.new(1,0,1))).Magnitude <= 31
                                if not (planar and math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z) then continue end

                                local pos = getWorldPos(item) or itemPos
                                local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                                if pos and hrp then
                                    tween(Vector3.new(pos.X, hrp.Position.Y, pos.Z))
                                    if autoCollectItems and autoFarmContainers then
                                        local pp = item:FindFirstChildOfClass("ProximityPrompt") or item:FindFirstChildWhichIsA("ProximityPrompt", true)
                                        if pp then pcall(function() fireproximityprompt(pp) end) end
                                    end
                                    local sold = sell()
                                    if sold ~= false then break end
                                end
                            end
                        end
                    else
                        task.wait(0.2)
                        local p = getWorldPos(holder)
                        if p then
                            local tw = tween(p + Vector3.new(0, 12, 0))
                            if tw == "success" then
                                if prompt then pcall(function() fireproximityprompt(prompt) end) end
                                pcall(function()
                                    StarterGui:SetCore("SendNotification", { Title = "Opened Container", Text = ("Container #%d was opened."):format(idx), Duration = 10 })
                                end)

                                if autoCollectItems then
                                    local mp = getWorldPos(model)
                                    if mp and tween(mp) == "success" then
                                        task.wait(2)
                                        if itemCache then
                                            for pass = 1, 3 do
                                                if pass > 1 then task.wait(1.5) end
                                                for _, item in ipairs(itemCache:GetChildren()) do
                                                    local primary = item:FindFirstChild("PrimaryPart"); if not primary then continue end
                                                    local itemPos = primary.Position
                                                    local contPos = getWorldPos(model:FindFirstChild("Container")) or getWorldPos(model)
                                                    if not contPos then continue end
                                                    local ok2, cf, size = pcall(function() local a,b=model:GetBoundingBox(); return a,b end)
                                                    if not ok2 or not cf or not size then continue end
                                                    local rel = cf:PointToObjectSpace(itemPos)
                                                    local half = size * 0.5
                                                    local planar = ((itemPos * Vector3.new(1,0,1)) - (contPos * Vector3.new(1,0,1))).Magnitude <= 31
                                                    local inside = planar and math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
                                                    if inside then
                                                        local pos = getWorldPos(item) or itemPos
                                                        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                                                        if pos and hrp then
                                                            tween(Vector3.new(pos.X, hrp.Position.Y, pos.Z))
                                                            if autoCollectItems and autoFarmContainers then
                                                                local pp = item:FindFirstChildOfClass("ProximityPrompt") or item:FindFirstChildWhichIsA("ProximityPrompt", true)
                                                                if pp then pcall(function() fireproximityprompt(pp) end) end
                                                            end
                                                            local sold = sell()
                                                            if sold ~= false then break end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

        else
            if autoBuyContainer then
                local holder = plotLogic and plotLogic:FindFirstChild("ContainerHolder")
                if not (holder and #holder:GetChildren() > 0) then

                    local function findClickableForLabel(txt, ignoreAncestorName)
                        local g = LP:FindFirstChild("PlayerGui"); if not g then return nil end
                        for _, d in ipairs(g:GetDescendants()) do
                            if d:IsA("TextLabel") and d.Text == txt then
                                if not (ignoreAncestorName and d:FindFirstAncestor(ignoreAncestorName)) then
                                    local a = d
                                    for _ = 1, 5 do
                                        a = a and a.Parent
                                        if not a then break end
                                        if a:IsA("TextButton") or a:IsA("ImageButton") then return a end
                                    end
                                    local c = d.Parent
                                    if c then
                                        local btn = c:FindFirstChildWhichIsA("TextButton", true)
                                                   or c:FindFirstChildWhichIsA("ImageButton", true)
                                        if btn then return btn end
                                        for _, s in ipairs(c:GetChildren()) do
                                            if s:IsA("TextButton") or s:IsA("ImageButton") then return s end
                                        end
                                    end
                                end
                            end
                        end
                        return nil
                    end

                    local function openComputer()
                        if not ensureRefs() then return false end
                        local pl = getPlotLogic(); if not pl then return false end
                        local comp = pl:FindFirstChild("ComputerSystem")
                        comp = comp and comp:FindFirstChild("ComputerProximityHolder")
                        local pos = getWorldPos(comp); if not pos then return false end
                        if tween(Vector3.new(pos.X, pos.Y + 5, pos.Z)) == "no root" then return false end
                        local pp = comp and (comp:FindFirstChildOfClass("ProximityPrompt")
                                   or comp:FindFirstChildWhichIsA("ProximityPrompt", true))
                        if not pp then return false end
                        pcall(function() fireproximityprompt(pp) end)
                        return true
                    end

                    local function openContainerShop()
                        local btn
                        local ok = waitUntil(function()
                            btn = findClickableForLabel("ContainerEx")
                            return btn ~= nil
                        end, 6)
                        if not ok or not btn then return false end
                        pcall(function() firesignal(btn.MouseButton1Click) end)
                        return true
                    end

                    local function selectContainer(name)
                        local want = name .. " Container"
                        local btn
                        local ok = waitUntil(function()
                            btn = findClickableForLabel(want, "InfoHolder")
                            return btn ~= nil
                        end, 6)
                        if not ok or not btn then return false end
                        pcall(function() firesignal(btn.MouseButton1Click) end)
                        return true
                    end

                    local function getMaxContainers()
                        if not ensureRefs() then return 0 end
                        local pl = getPlotLogic(); if not pl then return 0 end
                        local slotsFolder = pl:FindFirstChild("ContainerSlots")
                        if not slotsFolder then return 0 end
                        local badColor = "0 1 0 0 0 1 1 0 0 0 "
                        local slots = 0
                        for _, v in pairs(slotsFolder:GetChildren()) do
                            local lb = v:FindFirstChild("LeftBeam")
                            if not lb or tostring(lb.Color) ~= badColor then slots = slots + 1 end
                        end
                        return slots
                    end

                    local function buyToFill()
                        local pl = getPlotLogic(); if not pl then return false end
                        local h = pl:FindFirstChild("ContainerHolder")
                        if not h then return false end
                        local toFill = math.max(0, getMaxContainers() - #h:GetChildren())
                        if toFill <= 0 then return true end
                        task.wait(2)
                        local g = LP:FindFirstChild("PlayerGui")
                        local shop = g and g:FindFirstChild("MenusUI") and g.MenusUI:FindFirstChild("ContainerShop")
                        local buyBtn = shop and shop:FindFirstChild("RegularButton", true)
                        if not buyBtn then
                            local fb = findClickableForLabel("Regular")
                            if fb then buyBtn = fb end
                        end
                        if not buyBtn then return false end
                        for _ = 1, toFill do
                            pcall(function() firesignal(buyBtn.MouseButton1Click) end)
                            task.wait(0.12)
                        end
                        pcall(function()
                            local closeBtn = shop and shop:FindFirstChild("ButtonHolder") and shop.ButtonHolder:FindFirstChild("CloseButton")
                            if closeBtn then firesignal(closeBtn.MouseButton1Click) end
                        end)
                        local ok = waitUntil(function()
                            local pl2 = getPlotLogic()
                            local hh = pl2 and pl2:FindFirstChild("ContainerHolder")
                            return hh and (#hh:GetChildren() == getMaxContainers() or #hh:GetChildren() > 0) or false
                        end, 30)
                        return ok
                    end

                    local function buySelectedContainerWithRetry(name, retries)
                        retries = retries or 4
                        for attempt = 1, retries do
                            local pl = getPlotLogic()
                            local hh = pl and pl:FindFirstChild("ContainerHolder")
                            if hh and #hh:GetChildren() > 0 then return true end
                            StarterGui:SetCore("SendNotification", {
                                Title = ("Buying (attempt %d/%d)"):format(attempt, retries),
                                Text  = "Trying to purchase container...",
                                Duration = 5
                            })
                            task.wait(2)
                            if openComputer() and openContainerShop() and selectContainer(name) then
                                task.wait(2)
                                if buyToFill() then return true end
                            end
                            local appeared = waitUntil(function()
                                local pl2 = getPlotLogic()
                                local h2 = pl2 and pl2:FindFirstChild("ContainerHolder")
                                return h2 and #h2:GetChildren() > 0
                            end, math.max(1, 0.75 * attempt))
                            if appeared then return true end
                        end
                        return false
                    end

                    local ok = buySelectedContainerWithRetry(selectedContainer, 4)
                    if not ok then
                        StarterGui:SetCore("SendNotification", {
                            Title = "Buy failed",
                            Text  = "Will retry automatically.",
                            Duration = 6
                        })
                    end
                end
            end
        end

        task.wait(0.1)
    until false
end)

task.spawn(function()
    while true do
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if char and root then
            if isTweening then
                root.Velocity = Vector3.new()
                for _, v in ipairs(char:GetChildren()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            else
                for _, v in ipairs(char:GetChildren()) do
                    if v:IsA("BasePart") then v.CanCollide = true end
                end
            end
        end
        task.wait()
    end
end)
