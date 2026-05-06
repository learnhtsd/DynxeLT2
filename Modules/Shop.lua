-- [[ SHOP MODULE ]] --
-- Designed for Dynxe LT2 UI Engine

local ShopModule = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local Player            = Players.LocalPlayer

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     LOT REFERENCE                               │
-- └─────────────────────────────────────────────────────────────────┘
local _LOT = nil

function ShopModule.SetLOT(lot)
    _LOT = lot
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     NPC / REMOTE SETUP                          │
-- └─────────────────────────────────────────────────────────────────┘
local NPCs = {
    Thom    = workspace.Stores.WoodRUs.Thom,
    Corey   = workspace.Stores.FurnitureStore.Corey,
    Jenny   = workspace.Stores.CarStore.Jenny,
    Bob     = workspace.Stores.ShackShop.Bob,
    Timothy = workspace.Stores.FineArt.Timothy,
    Lincoln = workspace.Stores.LogicStore.Lincoln,
}

local Remote      = ReplicatedStorage.NPCDialog.PlayerChatted
local PromptChat  = ReplicatedStorage.NPCDialog.PromptChat
local SetChatting = ReplicatedStorage.NPCDialog.SetChattingValue
local Interact    = ReplicatedStorage.Interaction.ClientInteracted -- ← NEW

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                   PER-STORE CONFIGURATION                       │
-- └─────────────────────────────────────────────────────────────────┘
local StoreConfigs = {
    WoodRUs = {
        NPCName     = "Thom",
        ItemDropCF  = CFrame.new(268.5, 5.2,  67.4),
        PlayerBuyCF = CFrame.new(262.1, 3.2,  64.8),
    },
    FurnitureStore = {
        NPCName     = "Corey",
        ItemDropCF  = CFrame.new(477.2, 5.6, -1721.8),
        PlayerBuyCF = CFrame.new(481.4, 3.2, -1712.5),
    },
    CarStore = {
        NPCName     = "Jenny",
        ItemDropCF  = CFrame.new(528, 5.7, -1460),
        PlayerBuyCF = CFrame.new(524.9, 3.2, -1466.6),
    },
    ShackShop = {
        NPCName     = "Bob",
        ItemDropCF  = CFrame.new(260.4, 10.4, -2551.3),
        PlayerBuyCF = CFrame.new(256.7, 8.4, -2546.7),
    },
    FineArt = {
        NPCName     = "Timothy",
        ItemDropCF  = CFrame.new(5238.2, -164.0, 740.3),
        PlayerBuyCF = CFrame.new(5232.4, -166.0, 737.3),
    },
    LogicStore = {
        NPCName     = "Lincoln",
        ItemDropCF  = CFrame.new(4595.5, 9.4, -785.1),
        PlayerBuyCF = CFrame.new(4598.4, 7.0, -778.4),
    },
}

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                       FUNDS REMOTE                              │
-- └─────────────────────────────────────────────────────────────────┘
local GetFundsRemote = nil

local function FindRemoteRecursive(root, name)
    for _, child in ipairs(root:GetDescendants()) do
        if child.Name == name and child:IsA("RemoteFunction") then
            return child
        end
    end
    return nil
end

local function FetchFunds()
    if not GetFundsRemote then
        GetFundsRemote = FindRemoteRecursive(ReplicatedStorage, "GetFunds")
        if not GetFundsRemote then return nil end
    end

    local ok, result = pcall(function()
        return GetFundsRemote:InvokeServer()
    end)
    if ok and type(result) == "number" then
        return result
    end
    return nil
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                      NPC ID FETCHING                            │
-- └─────────────────────────────────────────────────────────────────┘
local NPCIDs     = {}
local IDsFetched = false

local function FetchNPCIDs()
    if IDsFetched then return end

    SetChatting:InvokeServer(true)

    local lastData
    local conn = PromptChat.OnClientEvent:Connect(function(_, chatData)
        lastData = chatData
    end)

    for name, npc in pairs(NPCs) do
        if not npc:FindFirstChild("Dialog") then
            Instance.new("Dialog", npc)
        end
        lastData = nil
        PromptChat:FireServer(true, npc, npc.Dialog)
        local t = tick()
        repeat task.wait() until lastData or tick() - t > 5
        if lastData then
            NPCIDs[name] = lastData.ID
        end
    end

    conn:Disconnect()
    SetChatting:InvokeServer(false)

    IDsFetched = true
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                   NPC ARG — BY STORE NAME                       │
-- └─────────────────────────────────────────────────────────────────┘
local function EnsureNPCID(npcName)  -- ← add this whole block here
    if NPCIDs[npcName] then return end

    local npc = NPCs[npcName]
    if not npc then return end
    if not npc:FindFirstChild("Dialog") then
        Instance.new("Dialog", npc)
    end

    pcall(function() SetChatting:InvokeServer(true) end)

    local lastData = nil
    local conn = PromptChat.OnClientEvent:Connect(function(_, chatData)
        lastData = chatData
    end)

    PromptChat:FireServer(true, npc, npc.Dialog)
    local t = tick()
    repeat task.wait() until lastData or tick() - t > 5

    conn:Disconnect()
    pcall(function() SetChatting:InvokeServer(false) end)

    if lastData then
        NPCIDs[npcName] = lastData.ID
    else
        warn("[Shop] Failed to fetch ID for NPC:", npcName)
    end
end

local function GetNPCArgForStore(storeName)
    local config = StoreConfigs[storeName]
    if not config then return nil end

    local npcName = config.NPCName
    local npc     = NPCs[npcName]
    if not npc then return nil end

    if not npc:FindFirstChild("Dialog") then
        Instance.new("Dialog", npc)
    end

    EnsureNPCID(npcName)  -- ← re-fetch if missing, every time

    return {
        ID        = NPCIDs[npcName],
        Character = npc,
        Name      = npcName,
        Dialog    = npc.Dialog,
    }
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │               SAFE INVOKE — HARD TIMEOUT PER CALL               │
-- └─────────────────────────────────────────────────────────────────┘
local INVOKE_TIMEOUT = 4

local function SafeInvoke(npcArg, action)
    local co   = coroutine.running()
    local done = false

    local fireThread = task.spawn(function()
        pcall(function()
            Remote:InvokeServer(npcArg, action)
        end)
        if not done then
            done = true
            task.spawn(co)
        end
    end)

    task.delay(INVOKE_TIMEOUT, function()
        if not done then
            done = true
            pcall(task.cancel, fireThread)
            task.spawn(co)
        end
    end)

    coroutine.yield()
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     POWER OF EASE PURCHASE                      │
-- └─────────────────────────────────────────────────────────────────┘
local POE_PRICE    = 10009000
local POE_TP_CF    = CFrame.new(1059.4, 17.2, 1130.3)
local POE_TIMEOUT  = 60
local POE_INTERVAL = 0.2

local function PurchasePowerOfEase()
    local funds = FetchFunds()
    if funds == nil then return end
    if funds < POE_PRICE then return end

    FetchNPCIDs()

    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local returnCF = root.CFrame
    root.CFrame = POE_TP_CF
    task.wait(0.15)

    local bestDist = math.huge
    local bestNPC, bestName

    for name, npc in pairs(NPCs) do
        local store = npc.Parent
        if store and store:FindFirstChild("Counter") then
            local dist = (store.Counter.CFrame.p - root.Position).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestNPC  = npc
                bestName = name
            end
        end
    end

    if not bestNPC then
        root.CFrame = returnCF
        return
    end

    if not bestNPC:FindFirstChild("Dialog") then
        Instance.new("Dialog", bestNPC)
    end

    local npcArg = {
        ID        = NPCIDs[bestName],
        Character = bestNPC,
        Name      = bestName,
        Dialog    = bestNPC.Dialog,
    }

    local deadline  = tick() + POE_TIMEOUT

    while tick() < deadline do
        SafeInvoke(npcArg, "Initiate")
        SafeInvoke(npcArg, "ConfirmPurchase")
        SafeInvoke(npcArg, "EndChat")

        local newFunds = FetchFunds()
        if newFunds and newFunds < funds then
            break
        end

        task.wait(POE_INTERVAL)
    end

    task.wait(0.1)
    local returnChar = Player.Character
    local returnRoot = returnChar and returnChar:FindFirstChild("HumanoidRootPart")
    if returnRoot then returnRoot.CFrame = returnCF end
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                       PURCHASE SEQUENCE                         │
-- └─────────────────────────────────────────────────────────────────┘
local SPAM_TIMEOUT       = 30
local INVOKE_GAP         = 0.05
local CYCLE_GAP          = 0.12
local FAIL_BACKOFF_AFTER = 8
local FAIL_BACKOFF_WAIT  = 0.6

local function IsSuccessParent(parent)
    if not parent then return false end
    if parent.Name == "PlayerModels" then return true end
    if parent == Player.Backpack     then return true end
    if parent == Player.Character    then return true end
    local current = parent
    while current do
        if current.Name == "PlayerModels" then return true end
        current = current.Parent
    end
    return false
end

local function CheckItemState(mainPart)
    if not mainPart then return "gone" end
    local parent = mainPart.Parent
    if IsSuccessParent(parent) then return "success" end
    if parent == nil then
        task.wait(0.12)
        local newParent = mainPart.Parent
        if IsSuccessParent(newParent) then return "success" end
        if newParent == nil             then return "gone"    end
    end
    return "pending"
end

local function FlushDialog(npcArg, count)
    count = count or 2
    for _ = 1, count do
        SafeInvoke(npcArg, "EndChat")
        task.wait(0.05)
    end
end

local function SpamPurchase(mainPart, npcArg, itemName)
    local failStreak = 0
    local deadline   = tick() + SPAM_TIMEOUT

    FlushDialog(npcArg, 2)
    task.wait(CYCLE_GAP)

    while tick() < deadline do
        SafeInvoke(npcArg, "Initiate")
        task.wait(INVOKE_GAP)

        local preState = CheckItemState(mainPart)
        if preState == "success" then
            FlushDialog(npcArg, 1)
            return true
        elseif preState == "gone" then
            FlushDialog(npcArg, 1)
            return false
        end

        SafeInvoke(npcArg, "ConfirmPurchase")

        local postState = CheckItemState(mainPart)
        SafeInvoke(npcArg, "EndChat")

        if postState == "success" then
            return true
        elseif postState == "gone" then
            return false
        end

        failStreak += 1
        if failStreak >= FAIL_BACKOFF_AFTER then
            FlushDialog(npcArg, 3)
            task.wait(FAIL_BACKOFF_WAIT)
            failStreak = 0
        else
            task.wait(CYCLE_GAP)
        end
    end

    FlushDialog(npcArg, 2)
    return false
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                      PURCHASE PART                              │
-- └─────────────────────────────────────────────────────────────────┘
local function PurchasePart(mainPart, item, originalCF)
    local storeName = item.Store
    local config    = StoreConfigs[storeName]

    if not config then return false end

    local itemDropCF  = config.ItemDropCF
    local playerBuyCF = config.PlayerBuyCF
    local itemName    = item.Name

    local success = _LOT.TeleportMany({ { target = mainPart, goalCF = itemDropCF } })

    if _LOT.IsBusy() then
        success = _LOT.WaitForBatch()
    end

    if not success then return false end

    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    originalCF = originalCF or root.CFrame
    root.CFrame = playerBuyCF
    task.wait(0.1)

    local npcArg = GetNPCArgForStore(storeName)
    if not npcArg or not npcArg.ID then return false end

    local purchased = SpamPurchase(mainPart, npcArg, itemName)

    if purchased then
        task.wait(0.05)
        if mainPart and mainPart.Parent then
            _LOT.TeleportMany({ { target = mainPart, goalCF = originalCF } })
        end
        local returnChar = Player.Character
        local returnRoot = returnChar and returnChar:FindFirstChild("HumanoidRootPart")
        if returnRoot then
            returnRoot.CFrame = originalCF * CFrame.new(0, 0, 3)
        end
    end

    return purchased
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     REMOTE ITEM LIST LOADER                     │
-- └─────────────────────────────────────────────────────────────────┘
local function LoadItemList()
    local genv   = getgenv()
    local user   = genv.User   or "learnhtsd"
    local repo   = genv.Repo   or "lt2"
    local branch = genv.Branch or "main"

    local url = string.format(
        "https://raw.githubusercontent.com/%s/%s/%s/LT2ItemList.lua?t=%s",
        user, repo, branch, tick()
    )

    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok or not result or result:find("404: Not Found") then
        return nil
    end

    local fn, parseErr = loadstring(result)
    if not fn then return nil end

    local ok2, items = pcall(fn)
    if not ok2 or type(items) ~= "table" then return nil end

    return items
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                   SHOPITEMS ↔ STORE MATCHER                     │
-- └─────────────────────────────────────────────────────────────────┘
local ShopItemsCache = {}

local function GetShopItemsForStore(storeName)
    if ShopItemsCache[storeName] ~= nil then
        return ShopItemsCache[storeName] or nil
    end

    local config = StoreConfigs[storeName]
    if not config then
        ShopItemsCache[storeName] = false
        return nil
    end

    local npc   = NPCs[config.NPCName]
    local store = npc and npc.Parent
    local anchor

    if store and store:FindFirstChild("Counter") then
        anchor = store.Counter.CFrame.p
    elseif store and store:IsA("Model") then
        local ok, piv = pcall(function() return store:GetPivot().Position end)
        if ok then anchor = piv end
    end

    if not anchor then
        ShopItemsCache[storeName] = false
        return nil
    end

    local stores = workspace:FindFirstChild("Stores")
    if not stores then
        ShopItemsCache[storeName] = false
        return nil
    end

    local bestContainer, bestDist = nil, math.huge

    for _, child in ipairs(stores:GetChildren()) do
        if child.Name ~= "ShopItems" then continue end

        local samplePos
        for _, desc in ipairs(child:GetDescendants()) do
            if desc:IsA("BasePart") then
                samplePos = desc.Position
                break
            end
        end

        if samplePos then
            local dist = (samplePos - anchor).Magnitude
            if dist < bestDist then
                bestDist      = dist
                bestContainer = child
            end
        end
    end

    ShopItemsCache[storeName] = bestContainer or false
    return bestContainer
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                      WORLD PATH RESOLVER                        │
-- └─────────────────────────────────────────────────────────────────┘
local function ResolveItemParts(item, limit)
    local stores = workspace:FindFirstChild("Stores")
    if not stores then return {} end

    local results = {}

    local function searchContainer(shopItems)
        for _, box in ipairs(shopItems:GetChildren()) do
            if #results >= limit then break end
            if not (box:IsA("Model") and box.Name == "Box") then continue end

            local nameVal = box:FindFirstChild("BoxItemName")
            if not (nameVal and nameVal:IsA("StringValue")) then continue end
            if nameVal.Value ~= item.BoxItemName then continue end

            local main = box:FindFirstChild("Main")
            if main and main:IsA("BasePart") and not main.Anchored then
                table.insert(results, main)
            end
        end
    end

    local storeName = item.Store
    if storeName then
        local targetContainer = GetShopItemsForStore(storeName)
        if targetContainer then
            searchContainer(targetContainer)
            return results
        end
    end

    for _, child in ipairs(stores:GetChildren()) do
        if #results >= limit then break end
        if child.Name ~= "ShopItems" then continue end
        searchContainer(child)
    end

    return results
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                    RESTOCK-AWARE BUY LOOP                       │
-- └─────────────────────────────────────────────────────────────────┘
local RESTOCK_POLL_RATE = 0.5
local RESTOCK_TIMEOUT   = 120

local _isBuying = false

local function RunBuyLoop(item, totalQty, pressedCF, onDone)
    _isBuying = true

    FetchNPCIDs()

    local bought       = 0
    local failed       = 0
    local restockTimer = 0

    while bought < totalQty and _isBuying do
        local stillNeed = totalQty - bought
        local parts     = ResolveItemParts(item, stillNeed)

        if #parts == 0 then
            task.wait(RESTOCK_POLL_RATE)
            restockTimer += RESTOCK_POLL_RATE

            if restockTimer >= RESTOCK_TIMEOUT then
                break
            end

            continue
        end

        restockTimer = 0

        for _, mainPart in ipairs(parts) do
            if not _isBuying      then break end
            if bought >= totalQty then break end

            if not mainPart or not mainPart.Parent then
                failed += 1
                continue
            end

            if _LOT.IsBusy() then _LOT.WaitForBatch() end

            local ok = PurchasePart(mainPart, item, pressedCF)
            if ok then
                bought += 1
            else
                failed += 1
            end
        end
    end

    _isBuying = false

    if onDone then onDone() end
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │              BLUEPRINT — PURCHASE WITHOUT ITEM TP               │
-- └─────────────────────────────────────────────────────────────────┘
local function PurchaseBlueprintPart(mainPart, item)
    local storeName = item.Store
    local config    = StoreConfigs[storeName]
    if not config then return false end

    -- TP the item to the store drop position so the server accepts the purchase
    local success = _LOT.TeleportMany({ { target = mainPart, goalCF = config.ItemDropCF } })
    if _LOT.IsBusy() then
        success = _LOT.WaitForBatch()
    end
    if not success then return false end

    -- TP player to the buy counter
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    root.CFrame = config.PlayerBuyCF
    task.wait(0.1)

    local npcArg = GetNPCArgForStore(storeName)
    if not npcArg or not npcArg.ID then return false end

    -- Purchase — intentionally no return TP after, blueprint box goes to PlayerModels
    return SpamPurchase(mainPart, npcArg, item.Name)
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │              BLUEPRINT — OPEN BOX FROM PLAYERMODELS             │
-- └─────────────────────────────────────────────────────────────────┘
local BOX_OPEN_TIMEOUT = 10

local function OpenBlueprintBox(boxItemName)
    local PlayerModels = workspace:FindFirstChild("PlayerModels")
    if not PlayerModels then return false end

    local deadline = tick() + BOX_OPEN_TIMEOUT

    while tick() < deadline do
        for _, model in ipairs(PlayerModels:GetChildren()) do
            -- Box models are named "Box Purchased by <PlayerName>"
            if model:IsA("Model") and model.Name:find("Box Purchased by") then
                local nameVal = model:FindFirstChild("PurchasedBoxItemName")
                if nameVal and nameVal.Value == boxItemName then
                    local char = Player.Character
                    local head = char and char:FindFirstChild("Head")
                    if head then
                        Interact:FireServer(model, "Open box", head.CFrame)
                        task.wait(0.5) -- let the box open before moving on
                        return true
                    end
                end
            end
        end
        task.wait(0.2)
    end

    warn("[Blueprints] Timed out waiting for box:", boxItemName)
    return false
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                   PURCHASE ALL BLUEPRINTS                       │
-- └─────────────────────────────────────────────────────────────────┘
local _isBuyingBlueprints = false

local function RunBlueprintLoop(ShopItems, onDone)
    _isBuyingBlueprints = true

    FetchNPCIDs()

    -- Capture return position before moving anywhere
    local char     = Player.Character
    local root     = char and char:FindFirstChild("HumanoidRootPart")
    local returnCF = root and root.CFrame

    -- Collect all blueprint items from the item list
    local blueprints = {}
    for _, item in ipairs(ShopItems) do
        if item.Name:find("Blueprint") then
            table.insert(blueprints, item)
        end
    end

    if #blueprints == 0 then
        warn("[Blueprints] No blueprint items found in item list.")
        _isBuyingBlueprints = false
        if onDone then onDone() end
        return
    end

    print("[Blueprints] Found " .. #blueprints .. " blueprints to purchase.")

    for _, item in ipairs(blueprints) do
        if not _isBuyingBlueprints then break end

        -- Find the shop box for this blueprint
        local parts = ResolveItemParts(item, 1)
        if #parts == 0 then
            warn("[Blueprints] No stock found for:", item.Name, "— skipping.")
            continue
        end

        local mainPart = parts[1]
        if not mainPart or not mainPart.Parent then
            warn("[Blueprints] mainPart gone for:", item.Name, "— skipping.")
            continue
        end

        -- Skip if player already owns this blueprint
        local blueprintsFolder = Player:FindFirstChild("PlayerBlueprints")
            and Player.PlayerBlueprints:FindFirstChild("Blueprints")
        if blueprintsFolder and blueprintsFolder:FindFirstChild(item.BoxItemName) then
            print("[Blueprints] Already owned, skipping:", item.Name)
            continue
        end

        -- Check funds before attempting purchase
        local funds = FetchFunds()
        if funds == nil or funds < item.Price then
            warn("[Blueprints] Not enough funds for:", item.Name, "(need $" .. item.Price .. ")")
            continue
        end

        print("[Blueprints] Purchasing:", item.Name)
        local purchased = PurchaseBlueprintPart(mainPart, item)

        if purchased then
            print("[Blueprints] Purchased! Opening box for:", item.Name)
            -- Use BoxItemName if available, fallback to Name
            local boxName = item.BoxItemName or item.Name
            OpenBlueprintBox(boxName)
        else
            warn("[Blueprints] Failed to purchase:", item.Name)
        end

        task.wait(0.2)
    end

    -- TP player back to where they were
    local returnChar = Player.Character
    local returnRoot = returnChar and returnChar:FindFirstChild("HumanoidRootPart")
    if returnRoot and returnCF then
        returnRoot.CFrame = returnCF
    end

    print("[Blueprints] All done!")
    _isBuyingBlueprints = false
    if onDone then onDone() end
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                         MODULE INIT                             │
-- └─────────────────────────────────────────────────────────────────┘
function ShopModule.Init(Tab, lot, GetImageFunc)
    if lot ~= nil then _LOT = lot end

    local GetImage = GetImageFunc
                  or getgenv().GetImage
                  or function() return nil end

    local ShopItems = LoadItemList()
    if not ShopItems or #ShopItems == 0 then
        Tab:CreateSection("Hardware Store")
        return
    end

    local SelectedItem = ShopItems[1]
    local Quantity     = 1

    local PurchaseBtn

    local function UpdateDisplay()
        if not SelectedItem or not PurchaseBtn then return end
        PurchaseBtn:SetText(("$%d"):format(SelectedItem.Price * Quantity))
    end

    local function SetBuyingState(buying)
        if not PurchaseBtn then return end
        if buying then
            PurchaseBtn:SetText("Stop")
        else
            UpdateDisplay()
        end
    end

    Tab:CreateSection("Stores")

    local Catalog = Tab:CreateImageSelector("Slect a Item", {
        MultiSelect = false,
        VisibleRows = 4,
        SlotSize    = UDim2.new(0, 73, 0, 73),
    }, function(name)
        for _, item in pairs(ShopItems) do
            if item.Name == name then
                SelectedItem = item
                break
            end
        end
        UpdateDisplay()
    end)

    for _, item in pairs(ShopItems) do
        pcall(function()
            local img = GetImage("", item.Image)
            Catalog:AddSlot(img, item.Name, "$" .. tostring(item.Price))
        end)
    end

    Tab:CreateSlider("Quantity", 1, 100, 1, function(val)
        Quantity = val
        UpdateDisplay()
    end)

    PurchaseBtn = Tab:CreateAction("Purchase", ("$%d"):format(ShopItems[1].Price), function()

        if _isBuying then
            _isBuying = false
            return
        end

        if not SelectedItem then return end

        if _LOT == nil then return end

        if not SelectedItem.Store then return end

        if not StoreConfigs[SelectedItem.Store] then return end

        if _LOT.IsBusy() then return end

        local funds = FetchFunds()
        if funds == nil then return end

        if funds < SelectedItem.Price then return end

        local totalCost = SelectedItem.Price * Quantity
        local targetQty = Quantity
        if funds < totalCost then
            targetQty = math.floor(funds / SelectedItem.Price)
        end

        local char      = Player.Character
        local root      = char and char:FindFirstChild("HumanoidRootPart")
        local pressedCF = root and root.CFrame

        SetBuyingState(true)

        task.spawn(function()
            RunBuyLoop(SelectedItem, targetQty, pressedCF, function()
                SetBuyingState(false)
            end)
        end)
    end, false)

    UpdateDisplay()
    ShopModule.UpdateDisplay = UpdateDisplay

    -- ┌──────────────────────────────────────────────────────────────┐
    -- │                        SPECIAL SECTION                       │
    -- └──────────────────────────────────────────────────────────────┘
    Tab:CreateSection("Special")

    Tab:CreateAction("Power of Ease ($10,009,000)", "Buy", function()
        task.spawn(PurchasePowerOfEase)
    end, false)

    -- ── NEW: Purchase All Blueprints ─────────────────────────────────

    -- Collect blueprint items from the loaded list
    local BlueprintItems = {}
    for _, item in ipairs(ShopItems) do
        if item.Name:find("Blueprint") then
            table.insert(BlueprintItems, item)
        end
    end

    local function CheckAllBlueprintsOwned()
        if #BlueprintItems == 0 then
            print("[Blueprints] BlueprintItems is empty — returning false")
            return false
        end
        local playerBP = Player:FindFirstChild("PlayerBlueprints")
        if not playerBP then
            print("[Blueprints] No PlayerBlueprints folder found — returning false")
            return false
        end
        local blueprintsFolder = playerBP:FindFirstChild("Blueprints")
        if not blueprintsFolder then
            print("[Blueprints] No Blueprints subfolder found — returning false")
            return false
        end
        local owned, total = 0, #BlueprintItems
        for _, item in ipairs(BlueprintItems) do
            if blueprintsFolder:FindFirstChild(item.BoxItemName) then
                owned += 1
            end
        end
        print(("[Blueprints] Owned %d / %d"):format(owned, total))
        return owned >= total
    end

    local BlueprintBtn

    local function GetTotalBlueprintCost()
        local blueprintsFolder = Player:FindFirstChild("PlayerBlueprints")
            and Player.PlayerBlueprints:FindFirstChild("Blueprints")
        local total = 0
        for _, item in ipairs(BlueprintItems) do
            local owned = blueprintsFolder and blueprintsFolder:FindFirstChild(item.BoxItemName)
            if not owned then
                total += item.Price
            end
        end
        return total
    end

    local function UpdateBlueprintBtnState()
        if not BlueprintBtn then return end
        if _isBuyingBlueprints then return end -- don't override Stop state
        local allOwned = CheckAllBlueprintsOwned()
        BlueprintBtn:SetDisabled(allOwned)
        if allOwned then
            BlueprintBtn:SetText("All Owned")
        else
            local total = GetTotalBlueprintCost()
            BlueprintBtn:SetText("$" .. tostring(total))
        end
    end

    BlueprintBtn = Tab:CreateAction("Purchase All Blueprints", "Buy", function()

        -- Toggle stop if already running
        if _isBuyingBlueprints then
            _isBuyingBlueprints = false
            UpdateBlueprintBtnState()
            return
        end

        BlueprintBtn:SetText("Stop")

        task.spawn(function()
            RunBlueprintLoop(ShopItems, function()
                UpdateBlueprintBtnState()
            end)
        end)

    end, false)

    -- Initial state check on load
    UpdateBlueprintBtnState()

    -- ── NEW: Purchase Rukiry Axe ──────────────────────────────────────
    local RUKIRY_ITEMS = {
        {
            BoxItemName = "CanOfWorms",
            GoalCF      = CFrame.new(317.3, 46.0, 1918.1),
        },
        {
            BoxItemName = "BagOfSand",
            GoalCF      = CFrame.new(319.5, 46.0, 1914.9),
        },
        {
            BoxItemName = "LightBulb",
            GoalCF      = CFrame.new(322.4, 43.6, 1916.4),
        },
    }

    local RUKIRY_PLAYER_CF = CFrame.new(320.6, 45.8, 1919.2)

    local RukiryBtn
    local _isBuyingRukiry = false

    local function PurchaseRukiryItem(mainPart, item, goalCF)
        local storeName = item.Store
        local config    = StoreConfigs[storeName]
        if not config then return false end

        -- TP item to store drop zone
        local success = _LOT.TeleportMany({ { target = mainPart, goalCF = config.ItemDropCF } })
        if _LOT.IsBusy() then _LOT.WaitForBatch() end
        if not success then return false end

        -- TP player to store counter
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return false end
        root.CFrame = config.PlayerBuyCF
        task.wait(0.1)

        local npcArg = GetNPCArgForStore(storeName)
        if not npcArg or not npcArg.ID then return false end

        local purchased = SpamPurchase(mainPart, npcArg, item.Name)

        if purchased then
            task.wait(0.05)

            -- Snapshot existing models in PlayerModels before opening
            local PlayerModels = workspace:FindFirstChild("PlayerModels")
            local existingModels = {}
            if PlayerModels then
                for _, m in ipairs(PlayerModels:GetChildren()) do
                    existingModels[m] = true
                end
            end

            -- Open the box
            local boxModel = mainPart and mainPart.Parent
            if boxModel and boxModel:IsA("Model") then
                local char = Player.Character
                local head = char and char:FindFirstChild("Head")
                if head then
                    Interact:FireServer(boxModel, "Open box", head.CFrame)
                end
            end

            -- Wait for the spawned item to appear (it's a new model in PlayerModels)
            local spawnedPart = nil
            local deadline = tick() + 5
            while tick() < deadline do
                task.wait(0.1)
                if PlayerModels then
                    for _, m in ipairs(PlayerModels:GetChildren()) do
                        if not existingModels[m] and m:IsA("Model") then
                            -- Match by ItemName value == BoxItemName
                            local itemNameVal = m:FindFirstChild("ItemName")
                            if not (itemNameVal and itemNameVal.Value == item.BoxItemName) then
                                continue
                            end
                            -- Confirm ownership via Owner.OwnerString
                            local ownerFolder = m:FindFirstChild("Owner")
                            local ownerString = ownerFolder and ownerFolder:FindFirstChild("OwnerString")
                            if not (ownerString and ownerString.Value == Player.Name) then
                                continue
                            end
                            local foundMain = m:FindFirstChild("Main")
                            if foundMain then
                                spawnedPart = foundMain
                                break
                            end
                        end
                    end
                end
                if spawnedPart then break end
            end

            -- TP the newly spawned item to the goal position
            if spawnedPart and spawnedPart.Parent then
                _LOT.TeleportMany({ { target = spawnedPart, goalCF = goalCF } })
                if _LOT.IsBusy() then _LOT.WaitForBatch() end
            else
                warn("[Rukiry] Could not find spawned item after box open")
            end
        end

        return purchased
    end

local function RunRukiryLoop()
        _isBuyingRukiry = true
        FetchNPCIDs()

        local returnChar = Player.Character
        local returnRoot = returnChar and returnChar:FindFirstChild("HumanoidRootPart")
        local rukiryReturnCF = returnRoot and returnRoot.CFrame

        for _, rukiryItem in ipairs(RUKIRY_ITEMS) do
            if not _isBuyingRukiry then break end

            -- Find matching item in ShopItems
            local itemDef = nil
            for _, shopItem in ipairs(ShopItems) do
                if shopItem.BoxItemName == rukiryItem.BoxItemName then
                    itemDef = shopItem
                    break
                end
            end

            if not itemDef then
                warn("[Rukiry] Item not found in list:", rukiryItem.BoxItemName)
                continue
            end

            -- Check funds
            local funds = FetchFunds()
            if funds == nil or funds < itemDef.Price then
                warn("[Rukiry] Not enough funds for:", itemDef.Name, "(need $" .. itemDef.Price .. ")")
                continue
            end

            -- Find part in world
            local parts = ResolveItemParts(itemDef, 1)
            if #parts == 0 then
                warn("[Rukiry] No stock found for:", itemDef.Name)
                continue
            end

            local mainPart = parts[1]
            if not mainPart or not mainPart.Parent then
                warn("[Rukiry] mainPart gone for:", itemDef.Name)
                continue
            end

            print("[Rukiry] Purchasing:", itemDef.Name)
            local purchased = PurchaseRukiryItem(mainPart, itemDef, rukiryItem.GoalCF)

            if purchased then
                print("[Rukiry] Placed:", itemDef.Name)
            else
                warn("[Rukiry] Failed:", itemDef.Name)
            end

            task.wait(0.2)
        end

        -- TP player to final position
        local returnChar = Player.Character
        local returnRoot = returnChar and returnChar:FindFirstChild("HumanoidRootPart")
        if returnRoot then
            returnRoot.CFrame = RUKIRY_PLAYER_CF
        end

        -- Wait for the Rukiry axe to spawn then pick it up
        print("[Rukiry] Waiting for axe to spawn...")
        local axeModel = nil
        local axeDeadline = tick() + 20
        while tick() < axeDeadline do
            task.wait(0.2)
            local PlayerModels = workspace:FindFirstChild("PlayerModels")
            if not PlayerModels then continue end

            local char = Player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")

            for _, m in ipairs(PlayerModels:GetChildren()) do
                if not (m:IsA("Model") and m.Name == "Model") then continue end

                -- Check ToolName == "Rukiryaxe"
                local toolName = m:FindFirstChild("ToolName")
                if not (toolName and toolName.Value == "Rukiryaxe") then continue end

                -- Check Owner.OwnerString is blank
                local ownerFolder = m:FindFirstChild("Owner")
                local ownerString = ownerFolder and ownerFolder:FindFirstChild("OwnerString")
                if not (ownerString and ownerString.Value == "") then continue end

                -- Check Owner.LastInteraction == 0
                local lastInteraction = ownerFolder and ownerFolder:FindFirstChild("LastInteraction")
                if not (lastInteraction and lastInteraction.Value == 0) then continue end

                -- Check within 50 studs of player
                if root then
                    local handle = m:FindFirstChild("Handle") or m.PrimaryPart
                    if handle then
                        local dist = (handle.Position - root.Position).Magnitude
                        if dist > 50 then continue end
                    end
                end

                axeModel = m
                break
            end

            if axeModel then break end
        end

        if axeModel then
            local handle = axeModel:FindFirstChild("Handle") or axeModel.PrimaryPart
            if handle then
                print("[Rukiry] Found axe, teleporting down 1 stud...")
                _LOT.TeleportMany({ { target = handle, goalCF = handle.CFrame * CFrame.new(0, -1, 0) } })
                if _LOT.IsBusy() then _LOT.WaitForBatch() end
                task.wait(0.1)
                print("[Rukiry] Picking up axe...")
                
                Interact:FireServer(axeModel, "Pick up tool", handle.CFrame)
                print("[Rukiry] Axe picked up!")
                task.wait(0.1)
                local retChar = Player.Character
                local retRoot = retChar and retChar:FindFirstChild("HumanoidRootPart")
                if retRoot and rukiryReturnCF then
                    retRoot.CFrame = rukiryReturnCF
                    print("[Rukiry] Returned to original position.")
                end
            else
                warn("[Rukiry] Axe found but no Handle/PrimaryPart")
            end
        else
            warn("[Rukiry] Axe did not spawn within timeout")
        end

        print("[Rukiry] Done!")
        _isBuyingRukiry = false
        RukiryBtn:SetText("$7,400")
    end

    RukiryBtn = Tab:CreateAction("Purchase Rukiry Axe", "$7,400", function()
        if _isBuyingRukiry then
            _isBuyingRukiry = false
            RukiryBtn:SetText("$7,400")
            return
        end

        RukiryBtn:SetText("Stop")
        task.spawn(RunRukiryLoop)
    end, false)

    -- Watch for blueprints being added OR removed (e.g. slot swap clears the folder)
    local bpFolder = Player:FindFirstChild("PlayerBlueprints")
        and Player.PlayerBlueprints:FindFirstChild("Blueprints")
    if bpFolder then
        bpFolder.ChildAdded:Connect(function()
            UpdateBlueprintBtnState()
        end)
        bpFolder.ChildRemoved:Connect(function()
            UpdateBlueprintBtnState()
        end)
    end
end

return ShopModule
