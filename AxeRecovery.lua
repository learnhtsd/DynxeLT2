local AxeRecoverModule = {}

-- ==========================================
--               SETTINGS
-- ==========================================
local Settings = {
    RespawnSettleDelay = 2.0,   -- seconds to wait after respawn before scanning
    PickupTimeout      = 3,     -- seconds to keep retrying one axe before skipping
    PickupFireRate     = 0.15,  -- seconds between remote fires during retry loop
    AxeRecoverRadius   = 50,    -- studs around death position to search
    MaxAxesToRecover   = 10,    -- hard cap on axes processed per respawn
}

-- ==========================================
--               SERVICES & VARS
-- ==========================================
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player           = Players.LocalPlayer
local ClientInteracted = ReplicatedStorage:WaitForChild("Interaction"):WaitForChild("ClientInteracted")

local _autoRecoverOn   = false
local _autoRecoverConn = nil 
local _deathPosition   = nil 
local _deathHumConn    = nil 

-- ==========================================
--               HELPERS
-- ==========================================

local function GetOwnedAxesNearDeath()
    local axes         = {}
    local playerModels = Workspace:FindFirstChild("PlayerModels")
    if not playerModels then return axes end

    for _, obj in ipairs(playerModels:GetDescendants()) do
        if not (obj.Name == "Model" and obj:IsA("Model")) then continue end

        local ownerFolder = obj:FindFirstChild("Owner")
        if not ownerFolder then continue end
        local ownerStr = ownerFolder:FindFirstChild("OwnerString")
        if not ownerStr or ownerStr.Value ~= player.Name then continue end

        if _deathPosition then
            local handle = obj:FindFirstChild("Handle") or obj.PrimaryPart
            if not handle then continue end
            if (handle.Position - _deathPosition).Magnitude > Settings.AxeRecoverRadius then continue end
        end

        table.insert(axes, obj)
    end
    return axes
end

local function CountHeldTools()
    local count = 0
    local containers = {player.Backpack, player.Character, Workspace:FindFirstChild(player.Name)}
    
    for _, container in ipairs(containers) do
        if container then
            for _, v in ipairs(container:GetChildren()) do
                if v.Name == "Tool" and v:IsA("Tool") then count += 1 end
            end
        end
    end
    return count
end

local function PickupAxeWithRetry(axe)
    local handle = axe:FindFirstChild("Handle") or axe.PrimaryPart
    if not handle then return false end

    local before   = CountHeldTools()
    local deadline = tick() + Settings.PickupTimeout

    while tick() < deadline do
        if not axe or not axe.Parent then return false end
        
        -- Fire remote without moving the character
        ClientInteracted:FireServer(axe, "Pick up tool", handle.CFrame)
        
        task.wait(Settings.PickupFireRate)
        if CountHeldTools() > before then
            return true
        end
    end
    return false
end

-- ==========================================
--               CORE LOGIC
-- ==========================================

local function OnRespawnedRecover(char)
    task.wait(Settings.RespawnSettleDelay)
    if not _autoRecoverOn then return end

    local axes = GetOwnedAxesNearDeath()
    if #axes == 0 then return end

    if #axes > Settings.MaxAxesToRecover then
        axes = {table.unpack(axes, 1, Settings.MaxAxesToRecover)}
    end

    local picked = 0
    for i, axe in ipairs(axes) do
        if PickupAxeWithRetry(axe) then
            picked += 1
            print(("[AxeRecoverModule] Recovered %d/%d"):format(i, #axes))
        end
    end
end

local function HookDeathPosition(char)
    if _deathHumConn then _deathHumConn:Disconnect() end
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    _deathHumConn = hum.Died:Connect(function()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        _deathPosition = hrp and hrp.Position or nil
    end)
end

local function Start()
    if _autoRecoverConn then return end
    _autoRecoverOn = true
    if player.Character then task.spawn(HookDeathPosition, player.Character) end
    _autoRecoverConn = player.CharacterAdded:Connect(function(char)
        task.spawn(HookDeathPosition, char)
        task.spawn(OnRespawnedRecover, char)
    end)
end

local function Stop()
    _autoRecoverOn = false
    if _autoRecoverConn then _autoRecoverConn:Disconnect(); _autoRecoverConn = nil end
    if _deathHumConn then _deathHumConn:Disconnect(); _deathHumConn = nil end
    _deathPosition = nil
end

function AxeRecoverModule.Init(Tab)
    Tab:CreateToggle("Axe Recovery", true, function(state)
        if state then Start() else Stop() end
    end)
    Start()
end

return AxeRecoverModule
