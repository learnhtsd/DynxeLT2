local AntiAFK = {}

function AntiAFK.Init(Tab)
    local Players = game:GetService("Players")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer


    -- STATE VARIABLES
    _G.AntiAFKEnabled = true


    -- UI SECTION
    Tab:CreateToggle("Anti-AFK", true, function(state)
        _G.AntiAFKEnabled = state
    end)


    -- MASTER LOGIC
    -- Connect to the Idled event of the player
    LocalPlayer.Idled:Connect(function()
        if _G.AntiAFKEnabled then
            -- This simulates a mouse movement/click on the screen to reset the AFK timer
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
            
            warn("[Anti-AFK]: Prevented disconnect at " .. os.date("%X"))
        end
    end)
end

return AntiAFK
