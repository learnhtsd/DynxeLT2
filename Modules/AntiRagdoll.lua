local AntiRagdoll = {}

function AntiRagdoll.Init(Tab)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer


    -- STATE VARIABLES
    _G.AntiRagdollEnabled = false


    -- CORE LOGIC
    local function SetStates(hum, state)
        if not hum then return end
        
        -- Disable the specific physics states that cause "falling over"
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not state)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not state)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not state)
        
        if state then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end


    -- UI SECTIONS
    Tab:CreateToggle("Anti-Ragdoll", false, function(s)
        _G.AntiRagdollEnabled = s
        
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            SetStates(hum, s)
        end
    end)
    -- MASTER LOOP
    RunService.Stepped:Connect(function()
        if not _G.AntiRagdollEnabled then return end
        
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if hum then
            -- If the humanoid enters a "fallen" state, force it back to GettingUp immediately
            local currentState = hum:GetState()
            if currentState == Enum.HumanoidStateType.FallingDown or currentState == Enum.HumanoidStateType.Ragdoll then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end)

    -- Ensure it stays active after death/respawn
    LocalPlayer.CharacterAdded:Connect(function(newChar)
        if _G.AntiRagdollEnabled then
            local hum = newChar:WaitForChild("Humanoid")
            task.wait(0.1) -- Small delay for character physics to initialize
            SetStates(hum, true)
        end
    end)
end

return AntiRagdoll
