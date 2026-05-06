local PlayerMovement = {}

function PlayerMovement.Init(Tab)
    local Players          = game:GetService("Players")
    local RunService       = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace        = game:GetService("Workspace")
    local LocalPlayer      = Players.LocalPlayer
    local Mouse            = LocalPlayer:GetMouse()
    local Camera           = Workspace.CurrentCamera

    -- ===========================
    -- THE REAL FIX: EXECUTOR GLOBALS
    -- getgenv() persists across script executions, unlike _G which often gets sandboxed.
    -- ===========================
    local env = getgenv and getgenv() or _G

    if env.PM_Connections then
        for _, conn in pairs(env.PM_Connections) do
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            end
        end
    end
    env.PM_Connections = {}

    -- ===========================
    -- STATE VARIABLES
    -- ===========================
    env.WalkSpeed     = 16
    env.SprintEnabled = false
    env.SprintSpeed   = 32
    env.IsSprinting   = false

    env.JumpHeight = 50
    env.InfJump    = false

    env.FlyMasterSwitch = true
    env.IsFlying        = false
    env.FlySpeed        = 100

    env.Noclip    = false
    env.WaterWalk = false
    env.ClickTP   = false

    local flyVelocity = nil
    local flyGyro     = nil

    -- ===========================
    -- CLEANUP ORPHANED OBJECTS
    -- ===========================
    local function CleanupOrphanedFlyObjects()
        local char = LocalPlayer.Character
        if not char then return end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")

        if hrp then
            -- Aggressively destroy ALL orphaned exploit movers, not just the first one
            for _, v in pairs(hrp:GetChildren()) do
                if v.Name == "ExploitFlyVelocity" or v.Name == "ExploitFlyGyro" then
                    v:Destroy()
                end
            end

            -- Zero out any residual velocity so the character isn't launched
            pcall(function() hrp.Velocity    = Vector3.new(0, 0, 0) end)
            pcall(function() hrp.RotVelocity = Vector3.new(0, 0, 0) end)
        end

        -- Reset PlatformStand and force Freefall to unstick the physics engine
        if hum then
            hum.PlatformStand = false
            task.delay(0.05, function()
                hum:ChangeState(Enum.HumanoidStateType.Freefall)
            end)
        end

        -- Reset globals so the new session starts clean
        env.IsFlying = false
        env.Noclip   = false
        flyVelocity = nil
        flyGyro     = nil
    end

    CleanupOrphanedFlyObjects()

    -- Track the CharacterAdded connection
    table.insert(env.PM_Connections, LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.1)
        CleanupOrphanedFlyObjects()
    end))

    -- ===========================
    -- PHYSICS & UTILS
    -- ===========================
    local function UpdateFlyPhysics(state)
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")

        if state and hrp and hum then
            if not flyVelocity or not flyVelocity.Parent then
                flyVelocity = Instance.new("BodyVelocity")
                flyVelocity.Name     = "ExploitFlyVelocity"
                flyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                flyVelocity.Velocity = Vector3.new(0, 0, 0)
                flyVelocity.Parent   = hrp
            end
            if not flyGyro or not flyGyro.Parent then
                flyGyro = Instance.new("BodyGyro")
                flyGyro.Name      = "ExploitFlyGyro"
                flyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
                flyGyro.P         = 10000
                flyGyro.Parent    = hrp
            end
            hum.PlatformStand = true
        else
            if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
            if flyGyro     then flyGyro:Destroy();     flyGyro     = nil end

            if hum then
                hum.PlatformStand = false
                task.wait(0.05)
                hum:ChangeState(Enum.HumanoidStateType.Freefall)
            end
        end
    end

    -- ===========================
    -- INPUT CONNECTIONS
    -- ===========================
    table.insert(env.PM_Connections, UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and env.ClickTP
            and input.UserInputType == Enum.UserInputType.MouseButton1
            and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0))
            end
        end
    end))

    table.insert(env.PM_Connections, UserInputService.JumpRequest:Connect(function()
        if env.InfJump then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState("Jumping") end
        end
    end))

    -- ===========================
    -- UI SECTIONS
    -- ===========================
    Tab:CreateSection("Movement")
    Tab:CreateSlider("Walk Speed",   16,  500,  16,  function(v) env.WalkSpeed   = v end)
    Tab:CreateSlider("Jump Height",  50,  800,  50,  function(v) env.JumpHeight  = v end)
    Tab:CreateSlider("Sprint Speed", 32,  1000, 32,  function(v) env.SprintSpeed = v end)
    Tab:CreateSlider("Fly Speed",    32,  1000, 100, function(v) env.FlySpeed    = v end)

    local SprintRow = Tab:CreateRow()
    SprintRow:CreateToggle("Sprint", false, function(s) env.SprintEnabled = s end)
    SprintRow:CreateKeybind("KeyBind", Enum.KeyCode.LeftShift, function()
        env.IsSprinting = not env.IsSprinting
    end)

    local FlyRow = Tab:CreateRow()
    FlyRow:CreateToggle("Fly", true, function(s)
        env.FlyMasterSwitch = s
        if not s and env.IsFlying then
            env.IsFlying = false
            UpdateFlyPhysics(false)
        end
    end)
    FlyRow:CreateKeybind("KeyBind", Enum.KeyCode.Q, function()
        if env.FlyMasterSwitch then
            env.IsFlying = not env.IsFlying
            UpdateFlyPhysics(env.IsFlying)
        end
    end)

    Tab:CreateSection("Camera Settings")
    Tab:CreateSlider("Field of View", 60, 120, 70, function(v) Camera.FieldOfView = v end)
    Tab:CreateToggle("Zoom", false, function(s)
        LocalPlayer.CameraMaxZoomDistance = s and 10000 or 128
        LocalPlayer.CameraMinZoomDistance = 0.5
    end):AddTooltip("Disable fog in Lighting settings for the best results. At extreme distances, fog can block your view.")

    Tab:CreateSection("Utility")
    Tab:CreateToggle("Infinite Jump", false, function(s) env.InfJump    = s end)
    Tab:CreateToggle("Noclip",        false, function(s) env.Noclip     = s end)
    Tab:CreateToggle("Water Walk",    false, function(s) env.WaterWalk  = s end)
    Tab:CreateToggle("Ctrl + Click TP", false, function(s) env.ClickTP  = s end)
    Tab:CreateAction("Reset Character", "Kill", function()
        if LocalPlayer.Character then LocalPlayer.Character:BreakJoints() end
    end)

    -- ===========================
    -- MASTER LOOP
    -- ===========================
    table.insert(env.PM_Connections, RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end

        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")

        if hum and not env.IsFlying then
            hum.PlatformStand = false
        end

        -- NOCLIP
        if env.Noclip then
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = false end
            end
        end

        -- SPEED / JUMP
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower    = env.JumpHeight
            if env.SprintEnabled and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or env.IsSprinting) then
                hum.WalkSpeed = env.SprintSpeed
            else
                hum.WalkSpeed = env.WalkSpeed
            end
        end

        -- WATER WALK
        if env.WaterWalk and hrp then
            if hrp.Position.Y <= 1 and hrp.Position.Y >= -5 then
                hrp.Velocity = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z)
                hrp.CFrame   = hrp.CFrame + Vector3.new(0, 0.1, 0)
            end
        end

        -- FLY
        if env.IsFlying and hrp then
            if not hrp:FindFirstChild("ExploitFlyVelocity") then UpdateFlyPhysics(true) end
            if flyVelocity and flyGyro then
                local moveVector = Vector3.new(0, 0, 0)
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + Camera.CFrame.LookVector  end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector - Camera.CFrame.LookVector  end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector - Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + Camera.CFrame.RightVector end
                local vel = (moveVector.Magnitude > 0) and (moveVector.Unit * env.FlySpeed) or Vector3.new(0, 0, 0)
                flyVelocity.Velocity = vel
                flyGyro.CFrame       = Camera.CFrame
            end
        end
    end))
end

return PlayerMovement
