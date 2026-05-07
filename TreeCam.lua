local TreeCam = {}

function TreeCam.Init(Tab)
    local Workspace = game:GetService("Workspace")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera
    
    -- STATE & ANCHOR
    _G.LoneTreeCamEnabled = false
    local TreePosition = Vector3.new(-50, -215, -1350)
    
    -- Create an invisible anchor for the camera to follow
    local Anchor = Instance.new("Part")
    Anchor.Name = "TreeCamAnchor"
    Anchor.Size = Vector3.new(1, 1, 1)
    Anchor.Position = TreePosition
    Anchor.Transparency = 1
    Anchor.CanCollide = false
    Anchor.Anchored = true
    Anchor.Parent = Workspace

    -- UI SECTION
    Tab:CreateToggle("Focus Lone Cave Tree", false, function(state)
        _G.LoneTreeCamEnabled = state
        
        if state then
            -- Set the camera to follow the anchor part
            Camera.CameraSubject = Anchor
        else
            -- Return the camera to the player
            local Character = LocalPlayer.Character
            if Character and Character:FindFirstChild("Humanoid") then
                Camera.CameraSubject = Character.Humanoid
            end
        end
    end)
end

return TreeCam
