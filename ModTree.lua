-- [[ MOD TREE MODULE ]] --
-- Designed for Dynxe LT2 UI Engine

local ModTreeModule = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Player = Players.LocalPlayer
local Mouse  = Player:GetMouse()

-- Same remote TreeModule uses for cutting
local RemoteProxy = ReplicatedStorage:WaitForChild("Interaction"):WaitForChild("RemoteProxy")

local _LOT = nil

function ModTreeModule.SetLOT(lot)
    _LOT = lot
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                        CONSTANTS                                │
-- └─────────────────────────────────────────────────────────────────┘
local MOD_TP_CF         = CFrame.new(-1410, 431, 1260)
local SETTLE_THRESHOLD  = 0.05    -- studs/s below which a part is "still"
local SETTLE_TIMEOUT    = 12      -- seconds before giving up on settle
local DISAPPEAR_TIMEOUT = 60      -- seconds to wait for section to break
local CHOP_FIRES        = 50      -- RemoteProxy fires per chop pass (mirrors TreeModule)
local CHOP_FIRE_DELAY   = 0.03    -- delay between each fire
local CHOP_CONFIRM_TIMEOUT = 15   -- seconds to wait for the new log model to appear

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                      AXE DAMAGE TABLE                           │
-- └─────────────────────────────────────────────────────────────────┘
-- Mirrors the damage table in TreeModule so the best available axe
-- is always used for the stump chop.
local AxeDamage = {
    ["The Many Axe"]           = 10.2,
    ["Amber Axe"]              = 3.39,
    ["Johiro"]                 = 1.8,
    ["Rukiryaxe"]              = 1.68,
    ["Bird Axe"]               = 1.65,
    ["Silver Axe"]             = 1.6,
    ["End Times Axe"]          = 1.58,
    ["Alpha Axe of Testing"]   = 1.5,
    ["Hardened Axe"]           = 1.45,
    ["Beta Axe of Bosses"]     = 1.45,
    ["Beesaxe"]                = 1.4,
    ["Gingerbread Axe"]        = 1.2,
    ["Steel Axe"]              = 0.93,
    ["CHICKEN AXE"]            = 0.9,
    ["Fire Axe"]               = 0.6,
    ["Plain Axe"]              = 0.55,
    ["Basic Hatchet"]          = 0.2,
    ["Candy Cane Axe"]         = 0,
}

local function ReadAxeName(tool)
    if not tool then return nil end
    local tipChild = tool:FindFirstChild("ToolTip")
    return (tipChild and tipChild:IsA("StringValue")) and tipChild.Value or tool.ToolTip
end

-- Returns the best axe tool + its name + its damage from Backpack/Character.
local function GetBestAxe()
    local bestTool, bestName, bestDmg = nil, nil, -1

    local function TryAdd(tool)
        if not tool:IsA("Tool") then return end
        local name = ReadAxeName(tool)
        if not name then return end
        local dmg = AxeDamage[name] or 1.0
        if dmg > bestDmg then
            bestTool = tool
            bestName = name
            bestDmg  = dmg
        end
    end

    local char = Player.Character
    if char then
        local equipped = char:FindFirstChildOfClass("Tool")
        if equipped then TryAdd(equipped) end
    end
    for _, tool in ipairs(Player.Backpack:GetChildren()) do
        TryAdd(tool)
    end

    return bestTool, bestName, bestDmg
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                   TREE ANALYSIS HELPER                          │
-- └─────────────────────────────────────────────────────────────────┘

-- Walks every descendant BasePart that has an ID child (wood sections,
-- excluding the named Stump part).  For each section it also reads the
-- ChildIDs folder (children named "Child" whose Value is another section's
-- ID).  Returns a table with:
--   .all     – every entry sorted ascending by id
--   .stump   – entry with the lowest id  (used for the base chop)
--   .target  – entry with the highest id that owns ≥1 Child
--              (this is the weld-holder the basePlate burns)
--   .tipID   – the highest Child value inside target.ChildIDs
--              (this is the detached section we send to the sawmill)
local function AnalyzeTree(treeModel)
    local entries = {}

    for _, part in ipairs(treeModel:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "Stump" then
            local idVal = part:FindFirstChild("ID")
            if idVal and (idVal:IsA("IntValue") or idVal:IsA("NumberValue")) then
                local childIDValues = {}
                local childFolder   = part:FindFirstChild("ChildIDs")
                if childFolder then
                    for _, child in ipairs(childFolder:GetChildren()) do
                        if child.Name == "Child"
                        and (child:IsA("IntValue") or child:IsA("NumberValue")) then
                            table.insert(childIDValues, child.Value)
                        end
                    end
                end
                table.insert(entries, {
                    part        = part,
                    id          = idVal.Value,
                    childIDs    = childIDValues,
                    hasChildren = #childIDValues > 0,
                })
            end
        end
    end

    -- Ascending by ID so entries[1] is always the stump/base
    table.sort(entries, function(a, b) return a.id < b.id end)

    local stumpEntry  = entries[1]

    -- Walk from the highest ID downward; first entry that has a Child is target
    local targetEntry = nil
    for i = #entries, 1, -1 do
        if entries[i].hasChildren then
            targetEntry = entries[i]
            break
        end
    end

    -- tipID = the highest Child value inside the target (the tip section)
    local tipID = nil
    if targetEntry then
        for _, cid in ipairs(targetEntry.childIDs) do
            if not tipID or cid > tipID then tipID = cid end
        end
    end

    return {
        all    = entries,
        stump  = stumpEntry,
        target = targetEntry,
        tipID  = tipID,
    }
end


-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     SETTLE DETECTION                            │
-- └─────────────────────────────────────────────────────────────────┘
local function WaitForSettle(treeModel)
    local deadline = tick() + SETTLE_TIMEOUT

    repeat
        task.wait(0.1)

        local moving = false
        for _, part in ipairs(treeModel:GetDescendants()) do
            if part:IsA("BasePart") and not part.Anchored then
                if part.AssemblyLinearVelocity.Magnitude  > SETTLE_THRESHOLD
                or part.AssemblyAngularVelocity.Magnitude > SETTLE_THRESHOLD then
                    moving = true
                    break
                end
            end
        end

        if not moving then return end
    until tick() >= deadline

    warn("[ModTree] Settle timeout — proceeding anyway.")
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                  CLICK-SELECTION HELPERS                        │
-- └─────────────────────────────────────────────────────────────────┘

-- Walks up the instance tree from a BasePart until it reaches a Model.
local function GetAncestorModel(instance)
    local current = instance
    while current and not current:IsA("Model") do
        current = current.Parent
    end
    return current
end

-- Waits for the player to left-click a Model that contains at least
-- one BasePart with an "ID" child (i.e. a felled/standing tree).
local function WaitForTreeClick(isModdingRef)
    local result = nil
    local done   = false
    local conn

    conn = Mouse.Button1Down:Connect(function()
        local target = Mouse.Target
        if not target then return end

        local model = GetAncestorModel(target)
        if not model then return end

        for _, desc in ipairs(model:GetDescendants()) do
            if desc:IsA("BasePart") and desc:FindFirstChild("ID") then
                result = model
                done   = true
                conn:Disconnect()
                return
            end
        end
    end)

    while not done and isModdingRef[1] do task.wait() end
    if conn.Connected then conn:Disconnect() end

    return result
end

-- Waits for the player to left-click a sawmill model.
-- Detection: model/ancestor named "Sawmill", or contains a "Log Sensor" part.
local function WaitForSawmillClick(isModdingRef)
    local result = nil
    local done   = false
    local conn

    conn = Mouse.Button1Down:Connect(function()
        local target = Mouse.Target
        if not target then return end

        local model = GetAncestorModel(target)
        if not model then return end

        local isSawmill = model.Name:lower():find("sawmill") ~= nil

        if not isSawmill then
            for _, desc in ipairs(model:GetDescendants()) do
                if desc.Name == "Log Sensor" or desc.Name == "LogSensor" then
                    isSawmill = true
                    break
                end
            end
        end

        if isSawmill then
            result = model
            done   = true
            conn:Disconnect()
        end
    end)

    while not done and isModdingRef[1] do task.wait() end
    if conn.Connected then conn:Disconnect() end

    return result
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                    STUMP CHOP HELPER                            │
-- └─────────────────────────────────────────────────────────────────┘

-- Fires RemoteProxy on the stump section's CutEvent enough times to
-- break a tiny piece off the bottom, identical to how TreeModule cuts.
local function ChopStumpSection(stumpSection, tool, axeName, damage)
    if not stumpSection or not stumpSection.Parent then return false end

    local idObj = stumpSection:FindFirstChild("ID")
    if not idObj then
        warn("[ModTree] Stump section has no ID child.")
        return false
    end

    -- Search the same three levels TreeModule does
    local cutEvent = stumpSection:FindFirstChild("CutEvent")
                  or stumpSection.Parent:FindFirstChild("CutEvent")
                  or (stumpSection.Parent.Parent
                      and stumpSection.Parent.Parent:FindFirstChild("CutEvent"))

    if not cutEvent then
        warn("[ModTree] CutEvent not found on stump section:", stumpSection:GetFullName())
        return false
    end

    -- Stand the player next to the cut point (mirrors TreeModule placement)
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = CFrame.new(
            stumpSection.Position + stumpSection.CFrame.RightVector * 4
        )
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        task.wait(0.1)
    end

    -- Cut at least 1 stud up from the bottom so the server accepts the hit.
    -- Formula mirrors FireCutSection in TreeModule (fraction * sizeY) but
    -- clamped so it never goes below 1.0 stud from the base.
    local sizeY  = stumpSection.Size.Y
    local height = math.clamp(
        sizeY * math.clamp(0.1 + (8 - sizeY) / 60, 0.1, 0.2),
        1.0,
        sizeY - 0.05
    )

    local args = {
        sectionId    = idObj.Value,
        faceVector   = Vector3.new(0, 0, -1),
        height       = height,
        hitPoints    = damage,
        cooldown     = 0,
        cuttingClass = "Axe",
        tool         = tool,
    }

    for _ = 1, CHOP_FIRES do
        RemoteProxy:FireServer(cutEvent, args)
        task.wait(CHOP_FIRE_DELAY)
    end

    return true
end



-- ┌─────────────────────────────────────────────────────────────────┐
-- │                  SECTION SEARCH BY ID                           │
-- └─────────────────────────────────────────────────────────────────┘

-- Priority order:
--   1. workspace.LogModels  — where the server puts properly detached sections
--   2. The rest of workspace — anywhere else (loose but not yet in LogModels)
-- The original treeModel is intentionally checked LAST because a section that
-- is still inside it is still part of the tree assembly; teleporting it via LOT
-- would drag the whole tree along.
local function FindSectionByID(treeModel, targetID)
    -- 1. workspace.LogModels (server-separated sections live here)
    local logModels = workspace:FindFirstChild("LogModels")
    if logModels then
        for _, model in ipairs(logModels:GetChildren()) do
            for _, desc in ipairs(model:GetDescendants()) do
                if desc:IsA("BasePart") then
                    local idVal = desc:FindFirstChild("ID")
                    if idVal and idVal.Value == targetID then return desc end
                end
            end
        end
    end

    -- 2. Anywhere in workspace that is NOT the original tree model
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("BasePart") and not desc:IsDescendantOf(treeModel) then
            local idVal = desc:FindFirstChild("ID")
            if idVal and idVal.Value == targetID then return desc end
        end
    end

    -- 3. Last resort: still inside the original tree model
    for _, desc in ipairs(treeModel:GetDescendants()) do
        if desc:IsA("BasePart") then
            local idVal = desc:FindFirstChild("ID")
            if idVal and idVal.Value == targetID then return desc end
        end
    end

    return nil
end


local function BuildTreeBatch(treeModel, anchorPart, goalCF)
    local anchorCF = anchorPart.CFrame
    local batch    = {}

    for _, part in ipairs(treeModel:GetDescendants()) do
        if part:IsA("BasePart") and not part.Anchored then
            local offset = anchorCF:Inverse() * part.CFrame
            table.insert(batch, { target = part, goalCF = goalCF * offset })
        end
    end

    return batch
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                      MAIN MOD SEQUENCE                          │
-- └─────────────────────────────────────────────────────────────────┘
local _isModding = false

local function RunModLoop(onDone)
    -- Use a reference table so click-wait loops can see cancellation.
    local aliveRef = { true }
    _isModding = true

    -- Capture where the player is before anything moves so we can return them.
    local char0     = Player.Character
    local root0     = char0 and char0:FindFirstChild("HumanoidRootPart")
    local preModCF  = root0 and root0.CFrame

    -- ── Step 2: Tree selection ────────────────────────────────────
    print("[ModTree] Click the tree you want to mod.")
    local treeModel = WaitForTreeClick(aliveRef)

    if not _isModding or not treeModel then
        _isModding = false
        if onDone then onDone() end
        return
    end
    print("[ModTree] Tree selected:", treeModel.Name)

    -- ── Step 3: Sawmill selection ─────────────────────────────────
    print("[ModTree] Click the sawmill.")
    local sawmill = WaitForSawmillClick(aliveRef)

    if not _isModding or not sawmill then
        _isModding = false
        if onDone then onDone() end
        return
    end
    print("[ModTree] Sawmill selected:", sawmill.Name)

    -- Find the Particles part of the sawmill — that's where the log needs to land.
    local sawmillParticles = sawmill:FindFirstChild("Particles", true)
    local sawmillCF
    if sawmillParticles and sawmillParticles:IsA("BasePart") then
        sawmillCF = sawmillParticles.CFrame
        print("[ModTree] Sawmill Particles part found.")
    else
        warn("[ModTree] Particles part not found on sawmill — falling back to bounding box.")
        sawmillCF = sawmill:GetBoundingBox()
    end

    -- ── Step 4: TP tree + player to MOD_TP_CF ────────────────────
    print("[ModTree] Analysing tree and teleporting to mod zone...")

    -- Analyse once here — the result is reused by steps 7, 9b, and 10.
    local analysis = AnalyzeTree(treeModel)

    if #analysis.all == 0 then
        warn("[ModTree] No wood sections found on tree.")
        _isModding = false
        if onDone then onDone() end
        return
    end

    if not analysis.target then
        warn("[ModTree] No weld-holding section found (no section owns a Child ID).")
        _isModding = false
        if onDone then onDone() end
        return
    end

    -- Only teleport the WoodSection with ID = 1 (base of the log).
    -- The rest follows via physics welds.
    local baseSection = nil
    for _, entry in ipairs(analysis.all) do
        if entry.id == 1 then baseSection = entry.part; break end
    end
    if not baseSection then baseSection = analysis.all[1].part end

    _LOT.TeleportMany({ { target = baseSection, goalCF = MOD_TP_CF } })
    if _LOT.IsBusy() then _LOT.WaitForBatch() end

    -- Move the player to a position beside the tree.
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = MOD_TP_CF * CFrame.new(0, 5, 10)
    end

    -- ── Step 5: Wait for tree to settle ──────────────────────────
    print("[ModTree] Waiting for tree to settle...")
    WaitForSettle(treeModel)
    print("[ModTree] Tree has settled.")

    -- ── Step 6: Find the correct BasePlate and shrink it ─────────
    -- There are multiple Lava-type objects under Region_Volcano.
    -- The right one is identified by having a TouchInterest child
    -- directly under its BasePlate.
    local basePlate = nil
    for _, child in ipairs(workspace.Region_Volcano:GetChildren()) do
        local bp = child:FindFirstChild("BasePlate")
        if bp and bp:FindFirstChildOfClass("TouchTransmitter") then
            basePlate = bp
            break
        end
        -- Roblox sometimes stores it as a TouchInterest instance
        if bp and bp:FindFirstChild("TouchInterest") then
            basePlate = bp
            break
        end
    end

    if not basePlate then
        warn("[ModTree] Could not find the fire BasePlate (no TouchInterest) in Region_Volcano.")
        _isModding = false
        if onDone then onDone() end
        return
    end

    local originalSize = basePlate.Size
    local originalCF   = basePlate.CFrame
    basePlate.Size = Vector3.new(1, 1, 1)

    -- ── Step 7: Pull target + tip from the pre-built analysis ────────
    -- target  = highest-ID section that owns at least one Child
    --           → this is the weld-holder the basePlate will burn
    -- tipID   = highest Child value inside target's ChildIDs
    --           → this is the section that detaches and goes to the sawmill
    local targetSection = analysis.target.part
    local tipID         = analysis.tipID

    print(("[ModTree] Target (weld-holder) ID = %d | Tip ID = %d")
        :format(analysis.target.id, tipID))

    -- ── Step 8: Lock basePlate onto the weld-holder for 1 full second ──
    -- Both Size and CFrame are written every Heartbeat tick.
    -- The Parent check is intentionally omitted — LT2 can reparent sections
    -- after a TP (making .Parent temporarily nil) which would silently stop
    -- the lock. We rely on pcall to handle a truly destroyed part instead.
    local targetCF   = targetSection.CFrame
    local lockConn = RunService.Heartbeat:Connect(function()
        pcall(function()
            targetCF             = targetSection.CFrame
            basePlate.Size       = Vector3.new(1, 1, 1)
            basePlate.CFrame     = targetCF
        end)
    end)

    task.wait(1.0)

    lockConn:Disconnect()
    basePlate.Size   = originalSize
    basePlate.CFrame = originalCF

    -- ── Step 9: Wait for the weld-holder section to disappear ─────
    print("[ModTree] Waiting for weld-holder section to be removed...")
    local disappearDeadline = tick() + DISAPPEAR_TIMEOUT

    while tick() < disappearDeadline do
        if not targetSection or not targetSection.Parent then break end
        task.wait(0.1)
    end

    if targetSection and targetSection.Parent then
        warn("[ModTree] Weld-holder section did not disappear within timeout.")
        _isModding = false
        if onDone then onDone() end
        return
    end
    print("[ModTree] Section removed.")

    -- ── Step 9b: Chop a tiny section from the stump (lowest ID) ──
    -- Fires in repeated batches of CHOP_FIRES until a new model appears
    -- in workspace.LogModels confirming the piece broke off.
    print("[ModTree] Chopping tiny piece from stump section...")

    local stumpSection = analysis.stump and analysis.stump.part

    local tool, axeName, damage = GetBestAxe()
    if not tool then
        warn("[ModTree] No axe found in Backpack — cannot chop stump. Proceeding anyway.")
    else
        print(("[ModTree] Using '%s' (dmg %.2f) for stump chop."):format(axeName, damage))

        local logModels  = workspace:FindFirstChild("LogModels")
        local beforeLogs = {}
        if logModels then
            for _, m in ipairs(logModels:GetChildren()) do
                beforeLogs[m] = true
            end
        end

        local chopDone     = false
        local chopDeadline = tick() + CHOP_CONFIRM_TIMEOUT

        local function NewLogAppeared()
            if not logModels then return false end
            for _, m in ipairs(logModels:GetChildren()) do
                if not beforeLogs[m] and m:IsA("Model") then return true end
            end
            return false
        end

        -- Keep firing in batches until the piece breaks off or we time out
        while not chopDone and tick() < chopDeadline do
            ChopStumpSection(stumpSection, tool, axeName, damage)
            chopDone = NewLogAppeared()
        end

        if chopDone then
            print("[ModTree] Stump chop confirmed — new log model appeared.")
        else
            warn("[ModTree] Chop confirmation timed out — proceeding anyway.")
        end
    end

    -- ── Step 10: TP the tip section (Child of weld-holder) to the sawmill ─
    -- Look up the tip part directly from our own analysis — every entry in
    -- analysis.all came from treeModel:GetDescendants(), so this is
    -- guaranteed to be our tree and not some random loose section elsewhere.
    task.wait(1.0)

    local highestSection = nil
    for _, entry in ipairs(analysis.all) do
        if entry.id == tipID then
            highestSection = entry.part
            break
        end
    end

    if not highestSection or not highestSection.Parent then
        warn(("[ModTree] Tip section (ID = %d) is no longer in the tree model."):format(tipID))
        _isModding = false
        if onDone then onDone() end
        return
    end

    print(("[ModTree] Found tip section (ID=%d), teleporting to sawmill..."):format(tipID))

    _LOT.TeleportMany({ { target = highestSection, goalCF = sawmillCF } })
    if _LOT.IsBusy() then _LOT.WaitForBatch() end

    -- Return the player to where they were before the mod sequence started.
    local returnChar = Player.Character
    local returnRoot = returnChar and returnChar:FindFirstChild("HumanoidRootPart")
    if returnRoot and preModCF then
        returnRoot.CFrame = preModCF
    end

    print("[ModTree] Done — log placed at sawmill, player returned.")
    _isModding = false
    aliveRef[1] = false
    if onDone then onDone() end
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                         MODULE INIT                             │
-- └─────────────────────────────────────────────────────────────────┘
function ModTreeModule.Init(Tab, lot)
    if lot ~= nil then _LOT = lot end

    Tab:CreateSection("Tree Modder")

    local ModBtn

    local function SetState(modding)
        if not ModBtn then return end
        ModBtn:SetText(modding and "Cancel" or "Mod")
    end

    ModBtn = Tab:CreateAction("Mod Tree", "Mod", function()
        if _isModding then
            _isModding = false
            SetState(false)
            return
        end

        SetState(true)

        task.spawn(function()
            RunModLoop(function()
                SetState(false)
            end)
        end)
    end, false)
end

return ModTreeModule
