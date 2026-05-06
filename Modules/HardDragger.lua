local HardDragger = {}

function HardDragger.Init(Tab)
    local Players = game:GetService("Players")
    local Player  = Players.LocalPlayer

    local Config = { Enabled = false }

    local MASSLESS_PROPS = PhysicalProperties.new(
        0.01, 0, 0, 0, 0
    )

    local _draggedPart    = nil
    local _originalProps  = nil
    local _hadCustomProps = false

    local function Restore()
        if not _draggedPart then return end
        pcall(function()
            if _hadCustomProps then
                _draggedPart.CustomPhysicalProperties = _originalProps
            else
                _draggedPart.CustomPhysicalProperties = nil
            end
        end)
        _draggedPart    = nil
        _originalProps  = nil
        _hadCustomProps = false
    end

    local function MakeMassless(part)
        if not part or not part:IsA("BasePart") then return end
        print("[HardDragger] Making massless:", part.Name, part:GetFullName())
        _draggedPart    = part
        _hadCustomProps = part.CustomPhysicalProperties ~= nil
        _originalProps  = part.CustomPhysicalProperties
        part.CustomPhysicalProperties = MASSLESS_PROPS
    end

    local function FindDraggedPart(dragger)
        -- Method 1: GetConnectedParts
        local connected = dragger:GetConnectedParts(true)
        for _, part in ipairs(connected) do
            if part ~= dragger and part:IsA("BasePart") and not part.Anchored then
                print("[HardDragger] Found via GetConnectedParts:", part.Name)
                return part
            end
        end

        -- Method 2: Check children of dragger for Weld/WeldConstraint
        for _, child in ipairs(dragger:GetDescendants()) do
            if child:IsA("Weld") or child:IsA("WeldConstraint") then
                local p0 = child.Part0
                local p1 = child.Part1
                if p0 and p0 ~= dragger and not p0.Anchored then
                    print("[HardDragger] Found via weld Part0:", p0.Name)
                    return p0
                end
                if p1 and p1 ~= dragger and not p1.Anchored then
                    print("[HardDragger] Found via weld Part1:", p1.Name)
                    return p1
                end
            end
        end

        -- Method 3: Proximity search — find closest unanchored BasePart
        local closest, closestDist = nil, 5  -- within 5 studs
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj.Anchored and obj ~= dragger then
                local dist = (obj.Position - dragger.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest     = obj
                end
            end
        end
        if closest then
            print("[HardDragger] Found via proximity:", closest.Name, "dist:", closestDist)
        end
        return closest
    end

    workspace.ChildAdded:Connect(function(child)
        if child.Name ~= "Dragger" then return end
        if not Config.Enabled then return end

        print("[HardDragger] Dragger appeared at", child.Position)

        -- Try immediately, then retry a few frames later if not found yet
        local function TryFind()
            local part = FindDraggedPart(child)
            if part then
                MakeMassless(part)
                return true
            end
            return false
        end

        task.defer(function()
            if not child.Parent then return end
            if not TryFind() then
                -- Retry up to 5 frames
                for _ = 1, 5 do
                    task.wait()
                    if not child.Parent then return end
                    if TryFind() then break end
                end
            end

            child.AncestryChanged:Connect(function()
                if not child.Parent then
                    print("[HardDragger] Dragger removed, restoring.")
                    Restore()
                end
            end)
        end)
    end)

    Tab:CreateSection("Hard Dragger")

    Tab:CreateToggle("Hard Dragger", false, function(state)
        Config.Enabled = state
        if not state then Restore() end
    end)
end

return HardDragger
