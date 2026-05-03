-- [[ LOOSE OBJECT TELEPORT MODULE ]] --
-- Designed for Dynxe LT2 UI Engine

local LooseObjectTeleport = {}

local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService   = game:GetService("GuiService")
local Players      = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player    = Players.LocalPlayer
local Camera    = workspace.CurrentCamera
local Mouse     = Player:GetMouse()

local ClientIsDragging = ReplicatedStorage:WaitForChild("Interaction"):WaitForChild("ClientIsDragging")

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                        SIGNAL UTILITY                           │
-- └─────────────────────────────────────────────────────────────────┘
local function NewSignal()
    local sig = { _listeners = {} }
    function sig:Connect(fn)
        local id = {}
        self._listeners[id] = fn
        return { Disconnect = function() self._listeners[id] = nil end }
    end
    function sig:Wait()
        local co = coroutine.running()
        local conn
        conn = self:Connect(function(...)
            conn:Disconnect()
            task.spawn(co, ...)
        end)
        return coroutine.yield()
    end
    function sig:_Fire(...)
        for _, fn in pairs(self._listeners) do
            task.spawn(fn, ...)
        end
    end
    return sig
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     CONFIGURATION & STATE                       │
-- └─────────────────────────────────────────────────────────────────┘
local Settings = {
    OwnershipTimeout = 3,
    FallbackWait     = 0.5,
    PreFireWait      = 0.05,
    PostObjectDelay  = 0.05,

    SelectionColor   = Color3.fromRGB(74, 120, 255),
    OutlineThickness = 0.02,

    StackX       = 2,
    StackY       = 1,
    StackZ       = 5,
    StackPadding = 0.1,

    KeepSelected = false,
}

local State = {
    SelectedObjects = {},
    SelectionBoxes  = {},
    Connections     = {},
    IsBusy          = false,
    BatchCancelled  = false,

    ClickSelectMode = false,
    GroupSelectMode = false,
    LassoMode       = false,
    LassoDragging   = false,
    LassoStartPos   = nil,
    LassoGui        = nil,
    LassoFrame      = nil,
    TpBtn = nil,

    StackMode         = false,
    StackPreviewParts = {},
    StackPreviewBoxes = {},
    StackPreviewConn  = nil,
    StackStartBtn     = nil,
    StackRotation     = CFrame.new(),

    Library        = nil,
    BatchCompleted = NewSignal(),
}

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                        HELPER FUNCTIONS                         │
-- └─────────────────────────────────────────────────────────────────┘
local function GetOwnerIdentity(model)
    if not model then return nil end
    local ownerValue = model:FindFirstChild("Owner")
    if ownerValue then
        local val = ownerValue.Value
        if typeof(val) == "Instance" and val:IsA("Player") then return val.Name end
        return tostring(val)
    end
    return nil
end

local function GetModelSignature(model)
    local mainPart  = model:FindFirstChild("Main") or model:FindFirstChildWhichIsA("BasePart")
    local mainClass = mainPart and mainPart.ClassName or "nil"
    local childKeys = {}
    for _, child in ipairs(model:GetChildren()) do
        table.insert(childKeys, child.ClassName .. ":" .. child.Name)
    end
    table.sort(childKeys)
    return mainClass .. "|" .. table.concat(childKeys, ",")
end

local function GetTreeClass(model)
    local tc = model:FindFirstChild("TreeClass")
    return tc and tostring(tc.Value) or nil
end

local function getObjectData(target)
    if not target or not target:IsA("BasePart") or target.Anchored then return nil end
    if target:IsDescendantOf(Player.Character) then return nil end
    local model = target:FindFirstAncestorOfClass("Model")
    local main  = (model and model:FindFirstChild("Main")) or target
    if main:IsA("BasePart") and not main.Anchored then
        return main, (model and model.Name or target.Name), model
    end
    return nil
end

local function UpdateVisuals()
    for _, v in pairs(State.SelectionBoxes) do v:Destroy() end
    State.SelectionBoxes = {}
    for _, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then
            local box         = Instance.new("SelectionBox")
            box.Color3        = Settings.SelectionColor
            box.LineThickness = Settings.OutlineThickness
            box.Adornee       = obj
            box.Parent        = game:GetService("CoreGui")
            table.insert(State.SelectionBoxes, box)
        end
    end
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                      CORE TELEPORT LOGIC                        │
-- └─────────────────────────────────────────────────────────────────┘
local function PlayerAlignedCFrame(position, root)
    local look     = root.CFrame.LookVector
    local flatLook = Vector3.new(look.X, 0, look.Z)
    if flatLook.Magnitude < 0.001 then
        flatLook = Vector3.new(0, 0, -1)
    end
    return CFrame.lookAt(position, position + flatLook.Unit)
end

local function FindLastInteraction(model)
    local ownerFolder = model:FindFirstChild("Owner")
    if ownerFolder then
        local li = ownerFolder:FindFirstChild("LastInteraction")
        if li then return li end
    end
    return model:FindFirstChild("LastInteraction")
end

local function TeleportSingle(target, goalCF, root)
    if not target or not target.Parent then return end

    local model          = target:FindFirstAncestorOfClass("Model") or target.Parent
    local lastInteracted = FindLastInteraction(model)

    root.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
    task.wait(Settings.PreFireWait)

    if lastInteracted then
        local co    = coroutine.running()
        local fired = false

        local conn = lastInteracted:GetPropertyChangedSignal("Value"):Connect(function()
            if not fired then
                fired = true
                task.spawn(co)
            end
        end)

        local fireLoop = task.spawn(function()
            local deadline = tick() + Settings.OwnershipTimeout

            local ok, err = pcall(function()
                while not fired and tick() < deadline do
                    ClientIsDragging:FireServer(model)
                    task.wait()
                end
            end)

            if not fired then
                fired = true
                task.spawn(co)
                if not ok then
                    warn(("[LOT] FireServer errored on '%s': %s")
                        :format(model.Name, tostring(err)))
                else
                    warn(("[LOT] LastInteraction on '%s' never changed within %.1fs — proceeding anyway.")
                        :format(model.Name, Settings.OwnershipTimeout))
                end
            end
        end)

        coroutine.yield()
        conn:Disconnect()
        task.cancel(fireLoop)
    else
        warn(("[LOT] No Owner.LastInteraction found on '%s' — using fallback wait."):format(model.Name))
        local deadline = tick() + Settings.FallbackWait
        while tick() < deadline do
            local ok, err = pcall(ClientIsDragging.FireServer, ClientIsDragging, model)
            if not ok then
                warn(("[LOT] Fallback FireServer errored on '%s': %s"):format(model.Name, tostring(err)))
                break
            end
            task.wait()
        end
    end

    if target and target.Parent then
        target.CFrame = goalCF
    end

    task.wait(Settings.PostObjectDelay)
end

local function RunBatch(jobs)
    if #jobs == 0 then
        State.BatchCompleted:_Fire(true, 0)
        return true
    end

    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not root then
        State.BatchCompleted:_Fire(false, 0)
        return false
    end

    State.IsBusy         = true
    State.BatchCancelled = false

    local savedCFrame = root.CFrame

    for _, job in ipairs(jobs) do
        if State.BatchCancelled then break end
        if job.target and job.target.Parent then
            local ok, err = pcall(TeleportSingle, job.target, job.goalCF, root)
            if not ok then
                warn(("[LOT] TeleportSingle failed, skipping object: %s"):format(tostring(err)))
            end
        end
    end

    if root and root.Parent then
        root.CFrame = savedCFrame
    end

    State.IsBusy = false

    local success = not State.BatchCancelled
    State.BatchCompleted:_Fire(success, #jobs)
    return success
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                         LASSO ENGINE                            │
-- └─────────────────────────────────────────────────────────────────┘
local function InitLassoGui()
    if State.LassoGui then State.LassoGui:Destroy() end
    local sg = Instance.new("ScreenGui")
    sg.Name           = "LassoDragGui"
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.BackgroundColor3       = Color3.fromRGB(60, 130, 255)
    frame.BackgroundTransparency = 0.75
    frame.BorderSizePixel        = 0
    frame.Visible                = false
    frame.ZIndex                 = 10
    frame.Parent                 = sg

    local stroke           = Instance.new("UIStroke")
    stroke.Color           = Color3.fromRGB(120, 180, 255)
    stroke.Thickness       = 1.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent          = frame

    State.LassoGui   = sg
    State.LassoFrame = frame
end

local function UpdateLassoFrame(currentPos)
    if not State.LassoFrame or not State.LassoStartPos then return end
    local minX = math.min(State.LassoStartPos.X, currentPos.X)
    local minY = math.min(State.LassoStartPos.Y, currentPos.Y)
    local maxX = math.max(State.LassoStartPos.X, currentPos.X)
    local maxY = math.max(State.LassoStartPos.Y, currentPos.Y)
    State.LassoFrame.Position = UDim2.fromOffset(minX, minY)
    State.LassoFrame.Size     = UDim2.fromOffset(maxX - minX, maxY - minY)
    State.LassoFrame.Visible  = true
end

local function SelectObjectsInLassoRect(startPos, endPos)
    local minX = math.min(startPos.X, endPos.X)
    local minY = math.min(startPos.Y, endPos.Y)
    local maxX = math.max(startPos.X, endPos.X)
    local maxY = math.max(startPos.Y, endPos.Y)
    if (maxX - minX) < 6 or (maxY - minY) < 6 then return end

    local playerModels = workspace:FindFirstChild("PlayerModels")
    if not playerModels then return end

    local inset = GuiService:GetGuiInset()

    for _, obj in ipairs(playerModels:GetDescendants()) do
        if obj:IsA("Model") then
            local part = obj:FindFirstChild("Main") or obj:FindFirstChildWhichIsA("BasePart")
            if part and not part.Anchored and not part:IsDescendantOf(Player.Character) then
                local screenPos, onScreen = Camera:WorldToScreenPoint(part.Position)
                local sx = screenPos.X + inset.X
                local sy = screenPos.Y + inset.Y
                if onScreen and screenPos.Z > 0 and sx >= minX and sx <= maxX and sy >= minY and sy <= maxY then
                    local idx = table.find(State.SelectedObjects, part)
                    if idx then
                        table.remove(State.SelectedObjects, idx)
                    else
                        table.insert(State.SelectedObjects, part)
                    end
                end
            end
        end
    end

    UpdateVisuals()
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                         STACK ENGINE                            │
-- └─────────────────────────────────────────────────────────────────┘
local function AllSelectedSameType()
    if #State.SelectedObjects == 0 then return false, "Queue is empty." end
    local refName, refSig
    for _, obj in ipairs(State.SelectedObjects) do
        if not (obj and obj.Parent) then continue end
        local model = obj:FindFirstAncestorOfClass("Model")
        local name  = model and model.Name or obj.Name
        local sig   = model and GetModelSignature(model) or (obj.ClassName .. ":" .. obj.Name)
        if not refName then
            refName = name; refSig = sig
        elseif name ~= refName or sig ~= refSig then
            return false, "Mixed item types — all items must be identical."
        end
    end
    return true, "OK"
end

local function GetStackPositions(origin, itemSize, countX, countY, countZ, totalItems, stackRotation)
    stackRotation = stackRotation or CFrame.new()
    local stepX = itemSize.X + Settings.StackPadding
    local stepY = itemSize.Y  -- no padding on Y, items sit flush on top of each other
    local stepZ = itemSize.Z + Settings.StackPadding

    -- Generate raw uncentered positions, filling X then Z then Y (layers upward last)
    local raw = {}
    for y = 0, countY - 1 do
        for z = 0, countZ - 1 do
            for x = 0, countX - 1 do
                table.insert(raw, Vector3.new(x * stepX, y * stepY, z * stepZ))
                if #raw >= totalItems then break end
            end
            if #raw >= totalItems then break end
        end
        if #raw >= totalItems then break end
    end

    -- Center X and Z around the actual placed items (not the full grid)
    -- Y stays grounded — no vertical centering
    local sumX, sumZ = 0, 0
    for _, p in ipairs(raw) do sumX += p.X; sumZ += p.Z end
    local cx = sumX / #raw
    local cz = sumZ / #raw

    local positions = {}
    for _, p in ipairs(raw) do
        local centered = Vector3.new(p.X - cx, p.Y, p.Z - cz)
        table.insert(positions, origin + stackRotation:VectorToWorldSpace(centered))
    end
    return positions
end

local function ClearStackPreview()
    if State.StackPreviewConn then State.StackPreviewConn:Disconnect() State.StackPreviewConn = nil end
    for _, box in ipairs(State.StackPreviewBoxes) do if box and box.Parent then box:Destroy() end end
    State.StackPreviewBoxes = {}
    for _, p in ipairs(State.StackPreviewParts) do if p and p.Parent then p:Destroy() end end
    State.StackPreviewParts = {}
end

local function SetTpBtnLabel(label)
    if State.TpBtn then
        if State.TpBtn.SetLabel then State.TpBtn:SetLabel(label)
        elseif State.TpBtn.SetText then State.TpBtn:SetText(label) end
    end
end

local function SetStackBtnLabel(label)
    if State.StackStartBtn then
        if State.StackStartBtn.SetLabel then State.StackStartBtn:SetLabel(label)
        elseif State.StackStartBtn.SetText then State.StackStartBtn:SetText(label) end
    end
end

local function StopStackMode(silent)
    State.StackMode     = false
    State.StackRotation = CFrame.new()
    ClearStackPreview()
    SetStackBtnLabel("Start")
end

local function StartStackMode()
    if State.StackMode then StopStackMode() return end

    local ok, reason = AllSelectedSameType()
    if not ok then return end

    local capacity = Settings.StackX * Settings.StackY * Settings.StackZ
    local stackCount = math.min(capacity, #State.SelectedObjects)

    local refSize = Vector3.new(4, 4, 4)
    for _, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then refSize = obj.Size break end
    end

    ClearStackPreview()
    for i = 1, stackCount do
        local p        = Instance.new("Part")
        p.Name         = "StackPreview_" .. i
        p.Size         = refSize
        p.Anchored     = true
        p.CanCollide   = false
        p.CanTouch     = false
        p.Transparency = 0.45
        p.Color        = Color3.fromRGB(80, 130, 255)
        p.Material     = Enum.Material.Neon
        p.CastShadow   = false
        p.Parent       = workspace
        table.insert(State.StackPreviewParts, p)

        local box         = Instance.new("SelectionBox")
        box.Color3        = Color3.fromRGB(140, 180, 255)
        box.LineThickness = 0.03
        box.Adornee       = p
        box.Parent        = game:GetService("CoreGui")
        table.insert(State.StackPreviewBoxes, box)
    end

    State.StackMode = true
    SetStackBtnLabel("Stop")

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    State.StackPreviewConn = RunService.RenderStepped:Connect(function()
        if not State.StackMode then return end
        local excludeList = {}
        if Player.Character then table.insert(excludeList, Player.Character) end
        for _, p in ipairs(State.StackPreviewParts) do table.insert(excludeList, p) end
        rayParams.FilterDescendantsInstances = excludeList

        local unitRay = Camera:ScreenPointToRay(Mouse.X, Mouse.Y)
        local result  = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, rayParams)
        local groundOrigin = result
            and (result.Position + Vector3.new(0, refSize.Y * 0.5, 0))
            or (unitRay.Origin + unitRay.Direction * 40)

        local positions = GetStackPositions(
            groundOrigin, refSize,
            Settings.StackX, Settings.StackY, Settings.StackZ,
            #State.StackPreviewParts, State.StackRotation
        )
        for i, ghostPart in ipairs(State.StackPreviewParts) do
            if positions[i] then
                ghostPart.CFrame = CFrame.new(positions[i]) * State.StackRotation
            end
        end
    end)
end

local function PerformStackExecute(hitPos)
    if not State.StackMode then return end
    local ok, reason = AllSelectedSameType()
    if not ok then StopStackMode() return end

    local refSize = Vector3.new(4, 4, 4)
    for _, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then refSize = obj.Size break end
    end

    local capacity   = Settings.StackX * Settings.StackY * Settings.StackZ
    local stackCount = math.min(capacity, #State.SelectedObjects)

    local groundOrigin  = hitPos + Vector3.new(0, refSize.Y * 0.5, 0)
    local goalPositions = GetStackPositions(
        groundOrigin, refSize,
        Settings.StackX, Settings.StackY, Settings.StackZ,
        stackCount, State.StackRotation
    )
    local capturedRotation = State.StackRotation
    StopStackMode(true)

    local jobs = {}
    for i = 1, stackCount do
        local obj = State.SelectedObjects[i]
        if obj and obj.Parent then
            table.insert(jobs, {
                target = obj,
                goalCF = CFrame.new(goalPositions[i] or groundOrigin) * capturedRotation
            })
        end
    end

    task.spawn(function()
        RunBatch(jobs)
        if not Settings.KeepSelected then State.SelectedObjects = {} end
        UpdateVisuals()
    end)
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     BUTTON / HOTKEY ACTIONS                     │
-- └─────────────────────────────────────────────────────────────────┘
local function PerformSingleSelect()
    local main = getObjectData(Mouse.Target)
    if main then
        local idx = table.find(State.SelectedObjects, main)
        if not idx then
            table.insert(State.SelectedObjects, main)
        else
            table.remove(State.SelectedObjects, idx)
        end
        UpdateVisuals()
    end
end

local function PerformGroupSelect()
    local _, itemName, targetModel = getObjectData(Mouse.Target)
    local targetOwnerIden = GetOwnerIdentity(targetModel)
    if not (itemName and targetOwnerIden and targetModel) then return end

    local targetSig       = GetModelSignature(targetModel)
    local targetTreeClass = GetTreeClass(targetModel)

    local playerModels = workspace:FindFirstChild("PlayerModels")
    if not playerModels then return end

    for i, obj in ipairs(playerModels:GetDescendants()) do
        if i % 1000 == 0 then task.wait() end
        if obj:IsA("Model") and obj.Name == itemName
            and GetOwnerIdentity(obj) == targetOwnerIden
            and GetModelSignature(obj) == targetSig
            and GetTreeClass(obj) == targetTreeClass then

            local part = obj:FindFirstChild("Main") or obj:FindFirstChildWhichIsA("BasePart")
            if part and not part.Anchored then
                local idx = table.find(State.SelectedObjects, part)
                if idx then
                    table.remove(State.SelectedObjects, idx)
                else
                    table.insert(State.SelectedObjects, part)
                end
            end
        end
    end
    UpdateVisuals()
end

local function PerformClear()
    if State.StackMode then StopStackMode(true) end
    State.SelectedObjects = {}
    State.BatchCancelled  = true
    UpdateVisuals()
end

local function PerformExecute()
    if State.IsBusy then
        State.BatchCancelled = true
        return
    end

    if #State.SelectedObjects == 0 or not Player.Character then return end
    local char = Player.Character
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local finalPos = root.Position

    local jobs = {}
    for _, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then
            table.insert(jobs, {
                target = obj,
                goalCF = PlayerAlignedCFrame(finalPos, root)
            })
        end
    end

    task.spawn(function()
        SetTpBtnLabel("Stop")
        local success = RunBatch(jobs)
        SetTpBtnLabel("Start")
        if not Settings.KeepSelected then State.SelectedObjects = {} end
        UpdateVisuals()
    end)
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                         PUBLIC API                              │
-- └─────────────────────────────────────────────────────────────────┘
function LooseObjectTeleport.Select(part)
    assert(typeof(part) == "Instance" and part:IsA("BasePart"), "LOT.Select: expected BasePart")
    if State.IsBusy then warn("LOT.Select: ignored — batch running.") return end
    if not table.find(State.SelectedObjects, part) then
        table.insert(State.SelectedObjects, part)
        UpdateVisuals()
    end
end

function LooseObjectTeleport.Deselect(part)
    local idx = table.find(State.SelectedObjects, part)
    if idx then table.remove(State.SelectedObjects, idx) UpdateVisuals() end
end

function LooseObjectTeleport.Clear()
    PerformClear()
end

function LooseObjectTeleport.TeleportTo(goalCF)
    assert(typeof(goalCF) == "CFrame", "LOT.TeleportTo: expected CFrame")
    if #State.SelectedObjects == 0 then return false end
    if State.IsBusy then warn("LOT.TeleportTo: ignored — batch running.") return false end
    local jobs = {}
    for _, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then table.insert(jobs, { target = obj, goalCF = goalCF }) end
    end
    local success = RunBatch(jobs)
    State.SelectedObjects = {}
    UpdateVisuals()
    return success
end

function LooseObjectTeleport.TeleportObjectTo(part, goalCF)
    assert(typeof(part) == "Instance" and part:IsA("BasePart"), "LOT.TeleportObjectTo: expected BasePart")
    assert(typeof(goalCF) == "CFrame", "LOT.TeleportObjectTo: expected CFrame")
    if State.IsBusy then warn("LOT.TeleportObjectTo: ignored — batch running.") return false end
    return RunBatch({ { target = part, goalCF = goalCF } })
end

function LooseObjectTeleport.TeleportMany(jobs)
    assert(type(jobs) == "table", "LOT.TeleportMany: expected table of jobs")
    if State.IsBusy then warn("LOT.TeleportMany: ignored — batch running.") return false end
    return RunBatch(jobs)
end

function LooseObjectTeleport.WaitForBatch()
    if not State.IsBusy then return true, 0 end
    return State.BatchCompleted:Wait()
end

function LooseObjectTeleport.IsBusy()
    return State.IsBusy
end

function LooseObjectTeleport.GetQueueSize()
    return #State.SelectedObjects
end

LooseObjectTeleport.BatchCompleted = nil

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                          INITIALIZE                             │
-- └─────────────────────────────────────────────────────────────────┘
function LooseObjectTeleport.Init(Tab, LibraryInstance)
    State.Library = LibraryInstance
    LooseObjectTeleport.BatchCompleted = State.BatchCompleted

    for _, conn in ipairs(State.Connections) do conn:Disconnect() end
    State.Connections = {}

    InitLassoGui()

    local Notice = Tab:CreateInfoBox()
    Notice:AddText("⚠  Server Performance Notice", {
        Bold  = true,
        Size  = 14,
    })
    Notice:AddDivider()
    Notice:AddText(
        "You may experience delays or failures in heavily populated servers " ..
        "or on low tick-rate servers. If objects fail to move, try increasing " ..
        "the Ownership Timeout slider below.",
        {
            Size    = 12,
            Opacity = 0.80,
            Italic  = true,
            Wrap    = true,
        }
    )

    local ClickToggle, GroupToggle, LassoToggle

    local function DisableOtherSelectionModes(except)
        if except ~= "click" and State.ClickSelectMode then
            State.ClickSelectMode = false
            if ClickToggle then ClickToggle:SetState(false) end
        end
        if except ~= "group" and State.GroupSelectMode then
            State.GroupSelectMode = false
            if GroupToggle then GroupToggle:SetState(false) end
        end
        if except ~= "lasso" and State.LassoMode then
            State.LassoMode     = false
            State.LassoDragging = false
            if State.LassoFrame then State.LassoFrame.Visible = false end
            if LassoToggle then LassoToggle:SetState(false) end
        end
    end

    ClickToggle = Tab:CreateToggle("Click Selection", false, function(val)
        State.ClickSelectMode = val
        if val then DisableOtherSelectionModes("click") end
    end)

    GroupToggle = Tab:CreateToggle("Group Selection", false, function(val)
        State.GroupSelectMode = val
        if val then DisableOtherSelectionModes("group") end
    end)

    LassoToggle = Tab:CreateToggle("Lasso Tool", false, function(val)
        State.LassoMode = val
        if val then
            DisableOtherSelectionModes("lasso")
        else
            State.LassoDragging = false
            if State.LassoFrame then State.LassoFrame.Visible = false end
        end
    end)
    Tab:CreateToggle("Keep Selection After TP", false, function(val) Settings.KeepSelected = val end)

    Tab:CreateSlider("Ownership Timeout (s)", 1, 10, Settings.OwnershipTimeout, function(val)
        Settings.OwnershipTimeout = val
    end):AddTooltip("Max seconds to fire the remote before giving up and moving the object anyway.")

    local MainRow = Tab:CreateRow()
    MainRow:CreateAction("Clear Selection", "Clear", PerformClear)
    State.TpBtn = MainRow:CreateAction("Teleport Selection", "Start", function()
        task.spawn(PerformExecute)
    end)

    Tab:CreateSection("Sorting")
    Tab:CreateSlider("X", 1, 40, Settings.StackX, function(val) Settings.StackX = val end)
    Tab:CreateSlider("Y", 1, 20, Settings.StackY, function(val) Settings.StackY = val end)
    Tab:CreateSlider("Z", 1, 40, Settings.StackZ, function(val) Settings.StackZ = val end)
    Tab:CreateSlider("Padding", 0, 1, Settings.StackPadding, function(val)
        Settings.StackPadding = val
    end, 1)

    local StackRow = Tab:CreateRow()
    State.StackStartBtn = StackRow:CreateAction("Sort Selected Objects", "Start", StartStackMode)

    table.insert(State.Connections, UIS.InputBegan:Connect(function(input, processed)
        if processed then return end

        if State.StackMode and input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.R then
                State.StackRotation = State.StackRotation * CFrame.Angles(0, math.rad(90), 0)
                return
            end
        end

        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if State.IsBusy then return end

        if State.StackMode then
            local excludeList = {}
            if Player.Character then table.insert(excludeList, Player.Character) end
            for _, p in ipairs(State.StackPreviewParts) do table.insert(excludeList, p) end
            local rayParams = RaycastParams.new()
            rayParams.FilterType                 = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = excludeList
            local unitRay = Camera:ScreenPointToRay(Mouse.X, Mouse.Y)
            local result  = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, rayParams)
            local hitPos  = result and result.Position or (unitRay.Origin + unitRay.Direction * 40)
            task.spawn(PerformStackExecute, hitPos)

        elseif State.LassoMode then
            State.LassoDragging = true
            State.LassoStartPos = UIS:GetMouseLocation()
            if State.LassoFrame then State.LassoFrame.Size = UDim2.fromOffset(0, 0) State.LassoFrame.Visible = false end

        elseif State.GroupSelectMode then
            PerformGroupSelect()

        elseif State.ClickSelectMode then
            PerformSingleSelect()
        end
    end))

    table.insert(State.Connections, UIS.InputChanged:Connect(function(input)
        if State.LassoDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateLassoFrame(UIS:GetMouseLocation())
        end
    end))

    table.insert(State.Connections, UIS.InputEnded:Connect(function(input)
        if State.LassoDragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
            State.LassoDragging = false
            if State.LassoFrame then State.LassoFrame.Visible = false end
            SelectObjectsInLassoRect(State.LassoStartPos, UIS:GetMouseLocation())
            State.LassoStartPos = nil
        end
    end))

    UpdateVisuals()
end

function LooseObjectTeleport.Unload()
    StopStackMode(true)
    for _, conn in ipairs(State.Connections) do conn:Disconnect() end
    for _, v in pairs(State.SelectionBoxes) do v:Destroy() end
    if State.LassoGui then State.LassoGui:Destroy() end
end

return LooseObjectTeleport
