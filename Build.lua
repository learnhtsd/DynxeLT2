local BuildModule = {}

function BuildModule.Init(Tab, LOT)
    local UIS     = game:GetService("UserInputService")
    local Players = game:GetService("Players")
    local CoreGui = game:GetService("CoreGui")
    local Player  = Players.LocalPlayer
    local Mouse   = Player:GetMouse()

    -- ══════════════════════════════════════════════════════════
    -- STATE
    -- ══════════════════════════════════════════════════════════
    local selectedClass  = nil
    local allPlanks      = {}
    local filteredPlanks = {}
    local yMin, yMax     = 0, 0
    local filterMax      = 0
    local plankIndex     = 1

    local pickingMode    = false
    local pickConn       = nil
    local bpClickMode    = false
    local bpClickConn    = nil

    -- Selection outline tracking
    local selectionBoxes = {}
    local outlineConnections = {}

    local selectBtn, MaxSlider, bpClickToggle, autoFillBtn

    -- ══════════════════════════════════════════════════════════
    -- OUTLINE MANAGEMENT
    -- ══════════════════════════════════════════════════════════
    local function ClearOutlines()
        for _, conn in ipairs(outlineConnections) do conn:Disconnect() end
        outlineConnections = {}
        for _, box in ipairs(selectionBoxes) do
            if box and box.Parent then box:Destroy() end
        end
        selectionBoxes = {}
    end

    local function RefreshBPStatus() end -- forward declaration, defined below

    local function DrawOutlines()
        ClearOutlines()
        for _, entry in ipairs(filteredPlanks) do
            if entry.part and entry.part.Parent then
                local box               = Instance.new("SelectionBox")
                box.Adornee             = entry.part
                box.Color3              = Color3.fromRGB(74, 120, 255)
                box.LineThickness       = 0.03
                box.SurfaceColor3       = Color3.fromRGB(74, 120, 255)
                box.SurfaceTransparency = 0.75
                box.Parent              = CoreGui
                table.insert(selectionBoxes, box)

                local conn = entry.part.Destroying:Connect(function()
                    box:Destroy()
                    for i, e in ipairs(filteredPlanks) do
                        if e.part == entry.part then table.remove(filteredPlanks, i); break end
                    end
                    for i, e in ipairs(allPlanks) do
                        if e.part == entry.part then table.remove(allPlanks, i); break end
                    end
                    plankIndex = math.max(1, math.min(plankIndex, #filteredPlanks))
                    RefreshBPStatus()
                end)
                table.insert(outlineConnections, conn)
            end
        end
    end

    -- ══════════════════════════════════════════════════════════
    -- HELPERS
    -- ══════════════════════════════════════════════════════════
    local function IsOwned(model)
        local owner = model:FindFirstChild("Owner")
        if not owner then return false end
        local ownerStr = owner:FindFirstChild("OwnerString")
        return ownerStr and ownerStr:IsA("StringValue") and ownerStr.Value == Player.Name
    end

    local function GetPlayerModels()
        return workspace:FindFirstChild("PlayerModels")
    end

    local function ResolveModel(target)
        local pm = GetPlayerModels()
        if not pm or not target then return nil end
        local current = target
        while current and current.Parent ~= pm do
            current = current.Parent
            if not current or current == workspace then return nil end
        end
        return (current and current:IsA("Model")) and current or nil
    end

    local function IsBlueprint(model)
        if not model or not model:IsA("Model") then return false end
        if not IsOwned(model) then return false end
        local typeVal = model:FindFirstChild("Type")
        return typeVal and typeVal:IsA("StringValue") and typeVal.Value == "Blueprint"
    end

    local function GetBlueprintCenter(model)
        if model.PrimaryPart then return model.PrimaryPart.Position end
        local sum, count = Vector3.new(0, 0, 0), 0
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                sum   = sum + part.Position
                count = count + 1
            end
        end
        return count > 0 and (sum / count) or Vector3.new(0, 0, 0)
    end

    local function ScanPlanksForClass(className)
        local pm, result = GetPlayerModels(), {}
        if not pm or not className then return result end
        for _, model in ipairs(pm:GetChildren()) do
            if model.Name == "Plank" and model:IsA("Model") and IsOwned(model) then
                local tc = model:FindFirstChild("TreeClass")
                if tc and tc:IsA("StringValue") and tc.Value == className then
                    local part = model:FindFirstChild("Main") or model:FindFirstChildWhichIsA("BasePart")
                    if part and part:IsA("BasePart") then
                        table.insert(result, {
                            model = model,
                            part  = part,
                            sizeY = math.floor(part.Size.Y * 10 + 0.5) / 10,
                        })
                    end
                end
            end
        end
        return result
    end

    local function GetOwnedBlueprints()
        local pm, result = GetPlayerModels(), {}
        if not pm then return result end
        for _, model in ipairs(pm:GetChildren()) do
            if IsBlueprint(model) then table.insert(result, model) end
        end
        return result
    end

    local function ApplyYFilter()
        filteredPlanks = {}
        for _, e in ipairs(allPlanks) do
            if e.sizeY <= filterMax then
                table.insert(filteredPlanks, e)
            end
        end
        plankIndex = 1
        DrawOutlines()
    end

    -- ══════════════════════════════════════════════════════════
    -- PLANK SELECTION
    -- ══════════════════════════════════════════════════════════
    Tab:CreateSection("Plank Selection")

    local function StopPickingMode()
        pickingMode = false
        if pickConn then pickConn:Disconnect(); pickConn = nil end
        if selectBtn then selectBtn:SetText("Start") end
    end

    local function OnPlankPicked(target)
        local model = ResolveModel(target)
        if not model or model.Name ~= "Plank" or not IsOwned(model) then
            StopPickingMode(); return
        end
        local tc = model:FindFirstChild("TreeClass")
        if not tc or not tc:IsA("StringValue") or tc.Value == "" then
            StopPickingMode(); return
        end

        selectedClass = tc.Value
        allPlanks     = ScanPlanksForClass(selectedClass)

        if #allPlanks > 0 then
            yMin, yMax = math.huge, -math.huge
            for _, e in ipairs(allPlanks) do
                if e.sizeY < yMin then yMin = e.sizeY end
                if e.sizeY > yMax then yMax = e.sizeY end
            end
            filterMax = yMax
            if MaxSlider then MaxSlider:SetValue(yMax) end
        else
            yMin, yMax, filterMax = 0, 0, 0
        end

        ApplyYFilter()
        RefreshBPStatus()
        StopPickingMode()
    end

    local function StartPickingMode()
        if pickingMode then StopPickingMode(); return end
        pickingMode = true
        if selectBtn then selectBtn:SetText("Click a Plank...") end

        pickConn = UIS.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            OnPlankPicked(Mouse.Target)
        end)
    end

    selectBtn = Tab:CreateAction("Select Plank Type", "Start", StartPickingMode)

    -- ══════════════════════════════════════════════════════════
    -- SIZE FILTER (slider only, no section header)
    -- ══════════════════════════════════════════════════════════
    MaxSlider = Tab:CreateSlider("Max Y Size", 0, 10, 1, function(val)
        filterMax = val
        if #allPlanks == 0 then return end
        ApplyYFilter()
        RefreshBPStatus()
    end, 1)

    -- ══════════════════════════════════════════════════════════
    -- BLUEPRINT FILL
    -- ══════════════════════════════════════════════════════════
    Tab:CreateSection("Blueprint Fill")
    -- ── Blueprint click mode ──────────────────────────────────
    local function StopBPClickMode()
        bpClickMode = false
        if bpClickConn then bpClickConn:Disconnect(); bpClickConn = nil end
        if bpClickToggle then bpClickToggle:SetState(false) end
    end

    local function OnBlueprintClicked(target)
        local model = ResolveModel(target)
        if not IsBlueprint(model) then return end
        if #filteredPlanks == 0 then
            warn("[Build] No filtered planks to place."); return
        end
        local entry = filteredPlanks[plankIndex]
        if not entry or not entry.part or not entry.part.Parent then
            plankIndex = (plankIndex % #filteredPlanks) + 1
            RefreshBPStatus(); return
        end
        task.spawn(function()
            if LOT then LOT.TeleportObjectTo(entry.part, CFrame.new(GetBlueprintCenter(model))) end
        end)
        plankIndex = (plankIndex % #filteredPlanks) + 1
        RefreshBPStatus()
    end

    local function StartBPClickMode()
        bpClickMode = true
        bpClickConn = UIS.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if not bpClickMode then return end
            OnBlueprintClicked(Mouse.Target)
        end)
    end

    bpClickToggle = Tab:CreateToggle("Click to Fill", false, function(state)
        if state then
            if #filteredPlanks == 0 then
                warn("[Build] Select and filter planks first.")
                bpClickToggle:SetState(false)
                return
            end
            RefreshBPStatus()
            StartBPClickMode()
        else
            StopBPClickMode()
        end
    end)

    local fillCancelled = false
    autoFillBtn = Tab:CreateAction("Fill All Blueprints", "Start", function()
        if autoFillBtn and autoFillBtn._running then
            fillCancelled = true
            return
        end

        if not LOT then warn("[Build] LOT not available.") return end
        if LOT.IsBusy() then warn("[Build] LOT busy.") return end
        if #filteredPlanks == 0 then warn("[Build] No filtered planks selected.") return end

        local blueprints = GetOwnedBlueprints()
        if #blueprints == 0 then warn("[Build] No owned blueprints found.") return end

        fillCancelled = false
        autoFillBtn._running = true
        autoFillBtn:SetText("Stop")

        task.spawn(function()
            for i, blueprint in ipairs(blueprints) do
                if fillCancelled then break end
                local entry = filteredPlanks[((i - 1) % #filteredPlanks) + 1]
                if not entry or not entry.part or not entry.part.Parent then continue end
                LOT.TeleportObjectTo(entry.part, CFrame.new(GetBlueprintCenter(blueprint)))
                LOT.WaitForBatch()
                task.wait(0.05)
            end
            autoFillBtn._running = false
            autoFillBtn:SetText("Start")
        end)
    end)
    
    -- ══════════════════════════════════════════════════════════
    -- LONG WIRE
    -- ══════════════════════════════════════════════════════════
    Tab:CreateSection("Other")
    
    local function SetWireLength(length)
        for _, item in next, game:GetService("ReplicatedStorage").ClientItemInfo:GetChildren() do
            if item.Name:lower():find("wire") then
                local maxLength = item:FindFirstChild("OtherInfo") and item.OtherInfo:FindFirstChild("MaxLength")
                if maxLength then
                    maxLength.Value = length
                end
            end
        end
    end
    
    Tab:CreateToggle("Long Wire", false, function(state)
        SetWireLength(state and 60 or 20)
    end)

    local undoStack  = {}
    local btoolsConn = nil
    
    Tab:CreateToggle("BTools", false, function(state)
        if state then
            undoStack = {}
            btoolsConn = UIS.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    
                local target = Mouse.Target
                if not target or not target:IsA("BasePart") then return end
                if target:IsDescendantOf(Player.Character or Instance.new("Folder")) then return end
                if target == workspace.Terrain then return end
                if target.Parent == workspace then return end
    
                table.insert(undoStack, {
                    part   = target,
                    parent = target.Parent,
                    cframe = target.CFrame,
                })
                target.Parent = nil
            end)
        else
            if btoolsConn then btoolsConn:Disconnect(); btoolsConn = nil end
            for i = #undoStack, 1, -1 do
                local entry = undoStack[i]
                if entry.part then
                    entry.part.Parent = entry.parent
                    if entry.part:IsA("BasePart") then
                        entry.part.CFrame = entry.cframe
                    end
                end
            end
            undoStack = {}
        end
    end)
    
    RefreshBPStatus()
end

return BuildModule
