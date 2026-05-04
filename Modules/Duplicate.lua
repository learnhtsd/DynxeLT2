local Duplication = {}
function Duplication.Init(Tab)
    local Players           = game:GetService("Players")
    local RunService        = game:GetService("RunService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer       = Players.LocalPlayer
    local env               = getgenv and getgenv() or _G

    env.DupeSource      = nil
    env.DupeTarget      = nil
    env.PM_Connections  = env.PM_Connections or {}
    env.DupeItems       = {
        Structures = false,
        Wires      = false,
        Furniture  = false,
        Gifts      = false,
        Axes       = false,
        Planks     = false,
    }

    -- ===========================
    -- SAFE RS FINDER
    -- ===========================
    local function SafeFind(parent, ...)
        local cur = parent
        for _, key in ipairs({...}) do
            if not cur then return nil end
            cur = cur:FindFirstChild(key)
        end
        return cur
    end

    -- Try to locate WireObjects and Sawmill type at runtime
    local function GetWireObject(name)
        -- Common paths LT2 has used
        local paths = {
            {"Purchasables", "WireObjects", name},
            {"PlaceStructure", "WireObjects", name},
            {"WireObjects", name},
        }
        for _, path in ipairs(paths) do
            local obj = SafeFind(ReplicatedStorage, table.unpack(path))
            if obj then return obj end
        end
        warn("[Dupe] Could not find WireObject: " .. tostring(name))
        return nil
    end

    local function GetSawmillType()
        local paths = {
            {"Purchasables", "Structures", "HardStructures", "Sawmill2", "Type"},
            {"Structures", "HardStructures", "Sawmill2", "Type"},
        }
        for _, path in ipairs(paths) do
            local obj = SafeFind(ReplicatedStorage, table.unpack(path))
            if obj then return obj end
        end
        warn("[Dupe] Could not find Sawmill2.Type")
        return nil
    end

    local function GetWireOtherInfo()
        local paths = {
            {"Purchasables", "WireObjects", "Wire", "OtherInfo"},
            {"WireObjects", "Wire", "OtherInfo"},
        }
        for _, path in ipairs(paths) do
            local obj = SafeFind(ReplicatedStorage, table.unpack(path))
            if obj then return obj end
        end
        warn("[Dupe] Could not find Wire.OtherInfo")
        return nil
    end

    -- ===========================
    -- HELPERS
    -- ===========================
    local function GetPlayerNames()
        local names = {}
        for _, p in pairs(Players:GetPlayers()) do
            table.insert(names, p.Name)
        end
        return names
    end

    local function FindPlayer(name)
        for _, p in pairs(Players:GetPlayers()) do
            if p.Name == name or p.Name:find(name) then return p end
        end
    end

    local function FindLand(owner)
        for _, v in pairs(workspace.Properties:GetChildren()) do
            if v:FindFirstChild("Owner") and v.Owner.Value == owner then
                return v
            end
        end
    end

    -- ===========================
    -- CORE DUPE LOGIC
    -- ===========================
    local function ExecuteDupe(sourcePlayerName, destPlayerName, library)
        local SlowMode = false
        local PS       = ReplicatedStorage.PlaceStructure

        -- Resolve source player
        local SourcePlayer = FindPlayer(sourcePlayerName)
        if not SourcePlayer then
            warn("[Dupe] Source player not found: " .. tostring(sourcePlayerName))
            if library then library:Notify("Dupe Failed", "Source player not found.", 4) end
            return
        end

        -- Resolve destination player
        local DestPlayer = FindPlayer(destPlayerName)
        if not DestPlayer then
            warn("[Dupe] Destination player not found: " .. tostring(destPlayerName))
            if library then library:Notify("Dupe Failed", "Destination player not found.", 4) end
            return
        end

        -- Find plots
        local SourceLand = FindLand(SourcePlayer)
        local DestLand   = FindLand(DestPlayer)

        if not SourceLand then
            if library then library:Notify("Dupe Failed", "Source has no plot.", 4) end
            warn("[Dupe] No source land found."); return
        end
        if not DestLand then
            if library then library:Notify("Dupe Failed", "Destination has no plot.", 4) end
            warn("[Dupe] No destination land found."); return
        end

        -- ── STRUCTURES ──────────────────────────────────────────────────
        if env.DupeItems.Structures then
            local CollectedTarget = {}
            local CollectedLocal  = {}
            local TotalBlueprints = 0

            for _, v in pairs(workspace.PlayerModels:GetChildren()) do
                if v:FindFirstChild("Owner") and v.Owner.Value == SourcePlayer
                and v:FindFirstChild("BuildDependentWood")
                and (v.Type and (v.Type.Value == "Structure" or v.Type.Value == "Furniture")) then
                    table.insert(CollectedTarget, {
                        WoodClass     = v:FindFirstChild("BlueprintWoodClass") and v.BlueprintWoodClass.Value,
                        OffSet        = (v:FindFirstChild("MainCFrame") and v.MainCFrame.Value or v.PrimaryPart.CFrame) - SourceLand.OriginSquare.Position,
                        BlueprintType = v.ItemName.Value,
                    })
                end
            end

            for _, Data in pairs(CollectedTarget) do
                PS.ClientPlacedBlueprint:FireServer(
                    Data.BlueprintType,
                    DestLand.OriginSquare.CFrame - Vector3.new(0, 20, 0),
                    LocalPlayer
                )
                if SlowMode and math.random(1, 2) ~= 1 then RunService.RenderStepped:Wait() end
            end

            local function blueprintCollected(model)
                if CollectedLocal[model.Name] then
                    for _, m in pairs(CollectedLocal[model.Name]) do
                        if m == model then return true end
                    end
                end
                return false
            end

            repeat
                for _, v in pairs(workspace.PlayerModels:GetChildren()) do
                    if v:FindFirstChild("Owner") and v.Owner.Value == LocalPlayer
                    and v:FindFirstChild("Type") and v.Type.Value == "Blueprint"
                    and not blueprintCollected(v) then
                        CollectedLocal[v.Name] = CollectedLocal[v.Name] or {}
                        table.insert(CollectedLocal[v.Name], v)
                        TotalBlueprints += 1
                    end
                end
                task.wait()
            until TotalBlueprints >= #CollectedTarget

            for _, Data in pairs(CollectedTarget) do
                local bp = CollectedLocal[Data.BlueprintType] and CollectedLocal[Data.BlueprintType][1]
                if bp then
                    table.remove(CollectedLocal[Data.BlueprintType], 1)
                    local pos = Data.OffSet + DestLand.OriginSquare.Position
                    PS.ClientPlacedStructure:FireServer(
                        bp.ItemName.Value, pos, LocalPlayer, Data.WoodClass, bp, not Data.WoodClass
                    )
                    if SlowMode and math.random(1, 2) ~= 1 then RunService.RenderStepped:Wait() end
                end
            end
        end

        -- ── WIRES ────────────────────────────────────────────────────────
        if env.DupeItems.Wires then
            for _, v in pairs(workspace.PlayerModels:GetChildren()) do
                if v:FindFirstChild("Owner") and v.Owner.Value == SourcePlayer
                and v:FindFirstChild("Type") and v.Type.Value == "Wire"
                and v:FindFirstChild("End1") then
                    local Points    = { v.End1.Position - SourceLand.OriginSquare.Position }
                    local pointCount = 1
                    for _, w in pairs(v:GetChildren()) do
                        if w.Name:find("Point") then pointCount += 1 end
                    end
                    for i = 2, pointCount do
                        local pt = v:FindFirstChild("Point" .. i)
                        if pt then table.insert(Points, pt.Position - SourceLand.OriginSquare.Position) end
                    end
                    table.insert(Points, v.End2.Position - SourceLand.OriginSquare.Position)
                    for i, p in pairs(Points) do Points[i] = p + DestLand.OriginSquare.Position end

                    local wireObj = GetWireObject(v.ItemName.Value)
                    if wireObj then
                        PS.ClientPlacedWire:FireServer(wireObj, Points)
                    end
                    if SlowMode and math.random(1, 2) ~= 1 then RunService.RenderStepped:Wait() end
                end
            end
        end

        -- ── FURNITURE ────────────────────────────────────────────────────
        if env.DupeItems.Furniture then
            local sawType   = GetSawmillType()
            local wireOther = GetWireOtherInfo()

            local function isValidFurniture(m)
                if m:FindFirstChild("Type")
                and (m.Type.Value == "Structure" or m.Type.Value == "Furniture" or m.Type.Value == "Vehicle Spot") then
                    return not (m:FindFirstChild("BuildDependentWood") or m:FindFirstChild("PurchasedBoxItemName"))
                end
                return false
            end

            local function spawnWireItem(itemName, position)
                if not sawType or not wireOther then return end
                local info = {
                    Name      = itemName.Value,
                    Type      = itemName.Name == "PurchasedBoxItemName" and itemName or sawType,
                    OtherInfo = wireOther,
                }
                PS.ClientPlacedWire:FireServer(info, { position.p, position.p })
            end

            local CollectedTarget = {}
            local CollectedLocal  = {}

            for _, m in pairs(workspace.PlayerModels:GetChildren()) do
                if m:FindFirstChild("Owner") and m.Owner.Value == SourcePlayer and isValidFurniture(m) then
                    local itemName = m:FindFirstChild("ItemName") or m:FindFirstChild("PurchasedBoxItemName")
                    local offset   = (m:FindFirstChild("MainCFrame") and m.MainCFrame.Value or m.PrimaryPart.CFrame) - SourceLand.OriginSquare.Position
                    if itemName.Name == "PurchasedBoxItemName" then
                        spawnWireItem(itemName, offset + DestLand.OriginSquare.Position)
                    else
                        spawnWireItem(itemName, DestLand.OriginSquare.CFrame - Vector3.new(0, 20, 0))
                    end
                    table.insert(CollectedTarget, { ItemName = itemName.Value, OffSet = offset })
                    if SlowMode and math.random(1, 2) ~= 1 then RunService.RenderStepped:Wait() end
                end
            end

            local remaining = {}
            for _, v in pairs(CollectedTarget) do table.insert(remaining, v) end

            local function needsModel(model)
                for i, d in pairs(remaining) do
                    if d.ItemName == model.ItemName.Value then
                        table.remove(remaining, i); return true
                    end
                end
                return false
            end

            repeat
                for _, m in pairs(workspace.PlayerModels:GetChildren()) do
                    if m.Name == "Wire" and m:FindFirstChild("Owner")
                    and m.Owner.Value == LocalPlayer and m.ItemName.Value ~= "Wire"
                    and needsModel(m) then
                        table.insert(CollectedLocal, m)
                    end
                end
                task.wait()
            until #remaining == 0

            local function grabFurniture(name)
                for i, m in pairs(CollectedLocal) do
                    if m.ItemName.Value == name then table.remove(CollectedLocal, i); return m end
                end
            end

            for _, d in pairs(CollectedTarget) do
                local model = grabFurniture(d.ItemName)
                if model then
                    local pos = d.OffSet + DestLand.OriginSquare.Position
                    PS.ClientPlacedStructure:FireServer(d.ItemName, pos, LocalPlayer, false, model, true)
                    if SlowMode and math.random(1, 2) ~= 1 then RunService.RenderStepped:Wait() end
                end
            end
        end

        -- ── LOOSE ITEMS (Gifts / Axes / Planks) ─────────────────────────
        if env.DupeItems.Gifts or env.DupeItems.Axes or env.DupeItems.Planks then
            local sawType   = GetSawmillType()
            local wireOther = GetWireOtherInfo()

            local function isValidItem(m)
                if m:FindFirstChild("Type") then
                    local t = m.Type.Value
                    if t == "Loose Item" or t == "Tool" or t == "Gift" then return true end
                    if (t == "Structure" or t == "Wire" or t == "Furniture")
                    and m:FindFirstChild("PurchasedBoxItemName") then return true end
                end
                return false
            end

            local function itemOnLand(pos)
                if math.abs(pos.X - SourceLand.OriginSquare.Position.X) > 101
                or math.abs(pos.Z - SourceLand.OriginSquare.Position.Z) > 101 then return false end
                for _, sq in pairs(SourceLand:GetChildren()) do
                    if sq.Name == "Square"
                    and math.abs(pos.X - sq.Position.X) < 21
                    and math.abs(pos.Z - sq.Position.Z) < 21 then return true end
                end
                return false
            end

            local function spawnLoose(itemName, position)
                if not sawType or not wireOther then return end
                local info = {
                    Name      = itemName.Value,
                    Type      = itemName.Name == "PurchasedBoxItemName" and itemName or sawType,
                    OtherInfo = wireOther,
                }
                PS.ClientPlacedWire:FireServer(info, { position.p, position.p })
            end

            local CollectedTarget = {}
            local CollectedLocal  = {}

            for _, m in pairs(workspace.PlayerModels:GetChildren()) do
                if m:FindFirstChild("Owner") and m.Owner.Value == SourcePlayer and isValidItem(m) then
                    local itemName = m:FindFirstChild("ItemName") or m:FindFirstChild("PurchasedBoxItemName")
                    local cf       = m:FindFirstChild("MainCFrame") and m.MainCFrame.Value or m.PrimaryPart.CFrame
                    local iname    = (itemName and itemName.Value or ""):lower()

                    local include = false
                    if env.DupeItems.Gifts  and m:FindFirstChild("Type") and m.Type.Value == "Gift" then include = true end
                    if env.DupeItems.Axes   and iname:find("axe")   then include = true end
                    if env.DupeItems.Planks and (iname:find("plank") or iname:find("wood")) then include = true end

                    if include and itemOnLand(cf.p) then
                        spawnLoose(itemName, DestLand.OriginSquare.CFrame - Vector3.new(0, 20, 0))
                        table.insert(CollectedTarget, { ItemName = itemName.Value, OffSet = cf - SourceLand.OriginSquare.Position })
                        if SlowMode and math.random(1, 2) ~= 1 then RunService.RenderStepped:Wait() end
                    end
                end
            end

            local remaining = {}
            for _, v in pairs(CollectedTarget) do table.insert(remaining, v) end

            local function needsItem(model)
                for i, d in pairs(remaining) do
                    if d.ItemName == model.ItemName.Value then table.remove(remaining, i); return true end
                end
                return false
            end

            repeat
                for _, m in pairs(workspace.PlayerModels:GetChildren()) do
                    if m.Name == "Wire" and m:FindFirstChild("Owner")
                    and m.Owner.Value == LocalPlayer
                    and (m.ItemName.Value ~= "Wire" or m:FindFirstChild("PurchasedBoxItemName"))
                    and needsItem(m) then
                        table.insert(CollectedLocal, m)
                    end
                end
                task.wait()
            until #remaining == 0

            local function grabItem(name)
                for i, m in pairs(CollectedLocal) do
                    if m.ItemName.Value == name then table.remove(CollectedLocal, i); return m end
                end
            end

            for _, d in pairs(CollectedTarget) do
                local model = grabItem(d.ItemName)
                if model then
                    local pos = d.OffSet + DestLand.OriginSquare.Position
                    if model:FindFirstChild("PurchasedBoxItemName") then
                        PS.ClientPlacedStructure:FireServer(false, pos, false, false, model)
                        model.Parent = nil
                    else
                        PS.ClientPlacedStructure:FireServer(d.ItemName, pos, LocalPlayer, false, model, true)
                    end
                    if SlowMode and math.random(1, 2) ~= 1 then RunService.RenderStepped:Wait() end
                end
            end
        end

        if library then library:Notify("Duplication", "Finished!", 5) end
        print("[Dupe] Finished!")
    end

    -- ===========================
    -- UI
    -- ===========================
    Tab:CreateSection("BASE DUPLICATION")

    local SourceDropdown = Tab:CreateDropdown("Copy From (Source):", GetPlayerNames(), GetPlayerNames()[1], function(s)
        env.DupeSource = s
    end)
    local TargetDropdown = Tab:CreateDropdown("Copy To (Destination):", GetPlayerNames(), GetPlayerNames()[1], function(s)
        env.DupeTarget = s
    end)

    local function RefreshLists()
        local names = GetPlayerNames()
        SourceDropdown:SetOptions(names)
        TargetDropdown:SetOptions(names)
    end
    table.insert(env.PM_Connections, Players.PlayerAdded:Connect(RefreshLists))
    table.insert(env.PM_Connections, Players.PlayerRemoving:Connect(RefreshLists))

    local isProcessing = false
    local StartButton

    StartButton = Tab:CreateAction("Duplicate Base", "Start", function()
        if isProcessing then return end
        if not env.DupeSource or not env.DupeTarget then
            warn("[Dupe] Select Source and Destination first!")
            return
        end
        isProcessing = true
        StartButton:SetDisabled(true)
        StartButton:SetText("Running...")
        task.spawn(function()
            ExecuteDupe(env.DupeSource, env.DupeTarget)
            isProcessing = false
            StartButton:SetDisabled(false)
            StartButton:SetText("Start")
        end)
    end, true)

    Tab:CreateSection("OBJECTS TO DUPLICATE")
    Tab:CreateToggle("Structures & Blueprints", false, function(s) env.DupeItems.Structures = s end)
    Tab:CreateToggle("Furniture",               false, function(s) env.DupeItems.Furniture  = s end)
    Tab:CreateToggle("Wires",                   false, function(s) env.DupeItems.Wires      = s end)
    Tab:CreateToggle("Gifts",                   false, function(s) env.DupeItems.Gifts      = s end)
    Tab:CreateToggle("Axes",                    false, function(s) env.DupeItems.Axes       = s end)
    Tab:CreateToggle("Planks / Wood",           false, function(s) env.DupeItems.Planks     = s end)
end

return Duplication
