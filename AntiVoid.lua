local AntiVoid = {}
function AntiVoid.Init(Tab)
    local RunService  = game:GetService("RunService")
    local Players     = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    _G.AntiVoidEnabled = false
    local VOID_THRESHOLD  = -60
    local FALLBACK_POSITION = Vector3.new(257.4, 3.2, 57.7)

    local function GetSafeDestination()
        -- 1. Try to find the player's plot
        local properties = workspace:FindFirstChild("Properties")
        if properties then
            for _, plot in ipairs(properties:GetChildren()) do
                local owner = plot:FindFirstChild("Owner")
                if owner and owner.Value == LocalPlayer then
                    local origin = plot:FindFirstChild("Origin")
                    if origin then
                        return origin.CFrame + Vector3.new(0, 5, 0)
                    end
                end
            end
        end
        -- 2. Fallback to the safe spawn position
        return CFrame.new(FALLBACK_POSITION)
    end

    Tab:CreateToggle("Anti-Void", false, function(state)
        _G.AntiVoidEnabled = state
    end)

    RunService.Heartbeat:Connect(function()
        if not _G.AntiVoidEnabled then return end
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Position.Y < VOID_THRESHOLD then
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.CFrame = GetSafeDestination()
        end
    end)
end
return AntiVoid
