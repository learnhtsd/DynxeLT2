local AntiFlingModule = {}

function AntiFlingModule.Init(Tab)
    local RunService  = game:GetService("RunService")
    local Players     = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local MaxHorizontalSpeed = 100
    local MaxRotationSpeed   = 10
    local MaxVerticalSpeed   = 250

    Tab:CreateToggle("Anti-Fling", false, function(state)
        _G.AntiFlingEnabled = state
    end)

    -- Connect after UI is built, and store it so Unload can clean it up
    local conn = RunService.Heartbeat:Connect(function()
        if not _G.AntiFlingEnabled then return end

        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        -- 1. Kill rotation
        if root.AssemblyAngularVelocity.Magnitude > MaxRotationSpeed then
            root.AssemblyAngularVelocity = Vector3.zero
        end

        -- 2. Limit horizontal velocity
        local vel  = root.AssemblyLinearVelocity
        local hVel = Vector3.new(vel.X, 0, vel.Z)
        if hVel.Magnitude > MaxHorizontalSpeed then
            local capped = hVel.Unit * MaxHorizontalSpeed
            root.AssemblyLinearVelocity = Vector3.new(capped.X, vel.Y, capped.Z)
        end

        -- 3. Kill extreme vertical
        if math.abs(root.AssemblyLinearVelocity.Y) > MaxVerticalSpeed then
            local v = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
        end
    end)

    _G.NexusConnections = _G.NexusConnections or {}
    table.insert(_G.NexusConnections, conn)
end

return AntiFlingModule
