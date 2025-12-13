-- =========================
-- Services
-- =========================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

-- =========================
-- Player / Character
-- =========================
local player = Players.LocalPlayer

-- =========================
-- SETTINGS
-- =========================
local TARGET_POSITION = Vector3.new(
    -132.98858642578125,
    4.006686687469482,
    274.6705322265625
)

local SPEED = 70
local RESPONSIVENESS = 60
local HOVER_HEIGHT = 5
local ARRIVAL_TOLERANCE = 0.5

-- 24 hours + 5 minutes
local RECONNECT_DELAY = (24 * 60 * 60) + (5 * 60)

-- =========================
-- NOCLIP (Bee Swarm – client side)
-- =========================
local noclipConn
local function enableNoclip(character)
    if noclipConn then return end
    noclipConn = RunService.Stepped:Connect(function()
        for _, v in ipairs(character:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
                v.CanTouch = true     -- allow token pickup
                v.CanQuery = false
            end
        end
    end)
end

local function disableNoclip()
    if noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end
end

-- =========================
-- Ground check
-- =========================
local function isGrounded(character, hrp)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {character}
    params.FilterType = Enum.RaycastFilterType.Blacklist

    return workspace:Raycast(
        hrp.Position,
        Vector3.new(0, -6, 0),
        params
    ) ~= nil
end

-- =========================
-- MAIN MOVEMENT ROUTINE
-- =========================
local function runMovement()
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local hrp = character:WaitForChild("HumanoidRootPart")

    local HOVER_POSITION = TARGET_POSITION + Vector3.new(0, HOVER_HEIGHT, 0)

    -- Prep
    humanoid.AutoRotate = false
    hrp.AssemblyAngularVelocity = Vector3.zero
    enableNoclip(character)

    -- Attachments
    local posAttachment = Instance.new("Attachment", hrp)
    local oriAttachment = Instance.new("Attachment", hrp)

    -- AlignPosition (glide)
    local alignPos = Instance.new("AlignPosition")
    alignPos.Attachment0 = posAttachment
    alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
    alignPos.Position = HOVER_POSITION
    alignPos.MaxVelocity = SPEED
    alignPos.Responsiveness = RESPONSIVENESS
    alignPos.MaxForce = math.huge
    alignPos.ApplyAtCenterOfMass = true
    alignPos.RigidityEnabled = false
    alignPos.Parent = hrp

    -- AlignOrientation (upright)
    local alignOri = Instance.new("AlignOrientation")
    alignOri.Attachment0 = oriAttachment
    alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
    alignOri.CFrame = CFrame.new()
    alignOri.MaxTorque = math.huge
    alignOri.Responsiveness = 100
    alignOri.RigidityEnabled = false
    alignOri.Parent = hrp

    local phase = "travel"
    local conn

    conn = RunService.Heartbeat:Connect(function()
        if phase == "travel" then
            if (hrp.Position - HOVER_POSITION).Magnitude <= ARRIVAL_TOLERANCE then
                phase = "drop"

                -- Stop glide
                alignPos:Destroy()
                posAttachment:Destroy()

                -- Turn noclip OFF before falling
                disableNoclip()
                hrp.AssemblyLinearVelocity = Vector3.new(0, -6, 0)
            end

        elseif phase == "drop" then
            if isGrounded(character, hrp) then
                conn:Disconnect()

                -- Cleanup
                alignOri:Destroy()
                oriAttachment:Destroy()

                humanoid.AutoRotate = true
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end)
end

-- =========================
-- RUN ONCE
-- =========================
runMovement()

-- =========================
-- RECONNECT AFTER 24H 5M
-- (same private server)
-- =========================
task.delay(RECONNECT_DELAY, function()
    if game.PrivateServerId ~= "" then
        TeleportService:TeleportToPrivateServer(
            game.PlaceId,
            game.ReservedServerAccessCode,
            { player }
        )
    else
        TeleportService:Teleport(game.PlaceId, player)
    end
end)
