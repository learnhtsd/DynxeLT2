-- FlashLight.lua
local FlashlightModule = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

function FlashlightModule.Init(Tab)
    local LocalPlayer = Players.LocalPlayer
    local ToolName = "PortableFlashlight"

    -- Helper function to create the Flashlight Tool
    local function CreateFlashlight()
        local Tool = Instance.new("Tool")
        Tool.Name = ToolName
        Tool.RequiresHandle = true
        Tool.CanBeDropped = false

        local Handle = Instance.new("Part")
        Handle.Name = "Handle"
        Handle.Size = Vector3.new(0.4, 0.4, 1.2)
        Handle.Color = Color3.fromRGB(30, 30, 30)
        Handle.Parent = Tool

        local Light = Instance.new("SpotLight")
        Light.Brightness = 3
        Light.Range = 60
        Light.Angle = 45
        Light.Face = Enum.NormalId.Front
        Light.Shadows = true
        Light.Enabled = true
        Light.Parent = Handle

        return Tool
    end

    -- Create the Toggle in the UI
    Tab:CreateToggle("Flashlight Tool", false, function(state)
        if state then
            -- Check if tool already exists to prevent duplicates
            if not LocalPlayer.Backpack:FindFirstChild(ToolName) and not LocalPlayer.Character:FindFirstChild(ToolName) then
                local NewTool = CreateFlashlight()
                NewTool.Parent = LocalPlayer.Backpack
                
                Library:Notify("Flashlight", "Flashlight added to inventory.", 3)
            end
        else
            -- Remove the tool from Backpack or Character if it's equipped
            local ToolInBackpack = LocalPlayer.Backpack:FindFirstChild(ToolName)
            local ToolInCharacter = LocalPlayer.Character:FindFirstChild(ToolName)

            if ToolInBackpack then ToolInBackpack:Destroy() end
            if ToolInCharacter then ToolInCharacter:Destroy() end
            
            Library:Notify("Flashlight", "Flashlight removed.", 3)
        end
    end):AddTooltip("Gives you a portable light source for dark areas.")
end

return FlashlightModule
