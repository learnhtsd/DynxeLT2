local PlayPositionNotify = {}

function PlayPositionNotify.Init(Tab, Library)
    local Players = game:GetService("Players")
    local Player = Players.LocalPlayer

    Tab:CreateSection("Location Tools")

    Tab:CreateAction("Get Position", "Copy", function()
        local Character = Player.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")

        if Root then
            local Pos = Root.Position
            -- Formats to 1 decimal place and creates the string
            local CoordString = string.format("%.1f, %.1f, %.1f", Pos.X, Pos.Y, Pos.Z)
            
            -- Copies the string to your Windows/Mac clipboard
            if setclipboard then
                setclipboard(CoordString)
                Library:Notify("Copied Position", CoordString, 3)
            else
                Library:Notify("Error", "Your executor does not support setclipboard!", 3)
            end
        else
            -- This correctly triggers if the Character or RootPart is missing
            Library:Notify("Error", "Character or RootPart not found!", 3)
        end
    end)
end

return PlayPositionNotify
