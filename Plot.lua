-- Plot.lua
local Plot = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")

function Plot.Init(Tab, Library)
    if not Tab then return warn("Plot Module: Tab was nil!") end

    local LocalPlayer        = Players.LocalPlayer
    local loadSaveRequests   = ReplicatedStorage:FindFirstChild("LoadSaveRequests")
    local propertyPurchasing = ReplicatedStorage:FindFirstChild("PropertyPurchasing")
    local interaction        = ReplicatedStorage:FindFirstChild("Interaction")
    local destroyStructure   = interaction and interaction:FindFirstChild("DestroyStructure")

    -- ==========================================
    -- SAVE & LOAD MANAGEMENT
    -- ==========================================
    Tab:CreateSection("Management")
    local selectedSlotToLoad = 1
    if Tab.CreateDropdown then
        Tab:CreateDropdown("Select Slot to Load", {"1", "2", "3", "4", "5", "6"}, "1", function(value)
            selectedSlotToLoad = tonumber(value)
        end)
    end

    Tab:CreateAction("Load Selected Slot", "Load", function()
        local RequestLoadRemote = loadSaveRequests and loadSaveRequests:FindFirstChild("RequestLoad")
        if RequestLoadRemote then
            RequestLoadRemote:InvokeServer(selectedSlotToLoad)
            if Library and Library.Notify then Library:Notify("SUCCESS", "Loading slot " .. selectedSlotToLoad, 5) end
        end
    end)

    local saveCooldownActive = false
    local saveBtn
    
    saveBtn = Tab:CreateAction("Save Slot", "Save", function()
        if saveCooldownActive then return end
        
        local currentSlot = LocalPlayer:FindFirstChild("CurrentSaveSlot")
        
        if not currentSlot or currentSlot.Value <= 0 then
            if Library and Library.Notify then 
                Library:Notify("ERROR", "No active slot detected. Load a slot first!", 5) 
            end
            return
        end

        local RequestSaveRemote = loadSaveRequests and loadSaveRequests:FindFirstChild("RequestSave")
        if RequestSaveRemote then
            if Library and Library.Notify then Library:Notify("SAVING", "Forcing save for slot " .. currentSlot.Value .. "...", 3) end
            
            local success, result = pcall(function()
                return RequestSaveRemote:InvokeServer(currentSlot.Value)
            end)

            if success then
                if Library and Library.Notify then Library:Notify("SUCCESS", "Save request sent!", 5) end
                
                -- Start Cooldown
                saveCooldownActive = true
                saveBtn:SetDisabled(true)
                
                task.spawn(function()
                    for i = 60, 1, -1 do
                        saveBtn:SetText("" .. i .. "s")
                        task.wait(1)
                    end
                    saveBtn:SetText("Save Slot")
                    saveBtn:SetDisabled(false)
                    saveCooldownActive = false
                end)
            else
                if Library and Library.Notify then Library:Notify("ERROR", "Save failed: " .. tostring(result), 5) end
            end
        else
            if Library and Library.Notify then Library:Notify("ERROR", "Save remote not found.", 5) end
        end
    end)

    local claimBtn
    local expandBtn
    local soldSignBtn
    local propertiesFolder = Workspace:FindFirstChild("Properties")
    local playerModels     = Workspace:FindFirstChild("PlayerModels")

    -- ==========================================
    -- SOLD SIGN FINDER
    -- Owner.OwnerString == LocalPlayer.Name
    -- Settings.PropertySoldSign == true
    -- ==========================================
    local function FindOwnedSoldSign()
        if not playerModels then return nil end
        for _, model in ipairs(playerModels:GetChildren()) do
            if not model:IsA("Model") then continue end
            local owner    = model:FindFirstChild("Owner")
            local ownerStr = owner and owner:FindFirstChild("OwnerString")
            if not ownerStr or ownerStr.Value ~= LocalPlayer.Name then continue end
            local settings = model:FindFirstChild("Settings")
            local soldFlag = settings and settings:FindFirstChild("PropertySoldSign")
            if soldFlag and soldFlag.Value == true then
                return model
            end
        end
        return nil
    end

    -- ==========================================
    -- BUTTON STATE UPDATERS
    -- ==========================================
    local function UpdateLandButtons()
        if not propertiesFolder then return end
        local hasLand      = false
        local landPieceCount = 0
        for _, plot in pairs(propertiesFolder:GetChildren()) do
            local owner = plot:FindFirstChild("Owner")
            if owner and owner.Value == LocalPlayer then
                hasLand = true
                for _, child in pairs(plot:GetChildren()) do
                    if child:IsA("BasePart") then landPieceCount += 1 end
                end
                break
            end
        end
        if claimBtn  then claimBtn:SetDisabled(hasLand) end
        if expandBtn then expandBtn:SetDisabled(not hasLand or landPieceCount >= 25) end
    end

    local function UpdateSoldSignButton()
        if soldSignBtn then
            soldSignBtn:SetDisabled(FindOwnedSoldSign() == nil)
        end
    end

    -- ==========================================
    -- LAND ACTIONS
    -- ==========================================

    -- ==========================================
    -- SOLD SIGN SECTION
    -- ==========================================
    Tab:CreateSection("Property Management")

    claimBtn = Tab:CreateAction("Claim Free Land", "Claim", function()
        if not propertiesFolder or not propertyPurchasing then return end
        local claimRemote = propertyPurchasing:FindFirstChild("ClientPurchasedProperty")
        for _, plot in pairs(propertiesFolder:GetChildren()) do
            local owner  = plot:FindFirstChild("Owner")
            local origin = plot:FindFirstChild("OriginSquare")
            if owner and origin and owner.Value == nil then
                claimRemote:FireServer(plot, origin.OriginCFrame.Value.p + Vector3.new(0, 3, 0))
                if Library and Library.Notify then Library:Notify("PROPERTY", "Claimed!", 3) end
                task.wait(0.5)
                if LocalPlayer.Character then LocalPlayer.Character:MoveTo(origin.Position) end
                break
            end
        end
    end)

    expandBtn = Tab:CreateAction("Max Land (Full Expand)", "Expand", function()
        if not propertiesFolder or not propertyPurchasing then return end
        local expandRemote = propertyPurchasing:FindFirstChild("ClientExpandedProperty")
        local playerPlot   = nil
        for _, plot in pairs(propertiesFolder:GetChildren()) do
            if plot.Owner.Value == LocalPlayer then playerPlot = plot break end
        end
        if playerPlot and playerPlot:FindFirstChild("OriginSquare") then
            local spos = playerPlot.OriginSquare.Position
            local offsets = {
                {0,40},{0,-40},{40,0},{-40,0},
                {40,40},{40,-40},{-40,40},{-40,-40},
                {80,0},{-80,0},{0,80},{0,-80},
                {80,80},{80,-80},{-80,80},{-80,-80},
                {40,80},{-40,80},{80,40},{80,-40},
                {-80,40},{-80,-40},{40,-80},{-40,-80}
            }
            for _, offset in ipairs(offsets) do
                expandRemote:FireServer(playerPlot, CFrame.new(spos.X + offset[1], spos.Y, spos.Z + offset[2]))
                task.wait(0.05)
            end
            if Library and Library.Notify then Library:Notify("SUCCESS", "Plot fully expanded!", 3) end
        end
    end)
    
    soldSignBtn = Tab:CreateAction("Delete 'Sold To' Sign", "Delete", function()
        if not destroyStructure then
            if Library and Library.Notify then Library:Notify("ERROR", "DestroyStructure remote not found.", 3) end
            return
        end
        local sign = FindOwnedSoldSign()
        if not sign then
            if Library and Library.Notify then Library:Notify("ERROR", "No sold property sign found.", 3) end
            UpdateSoldSignButton()
            return
        end
        destroyStructure:FireServer(sign)
        if Library and Library.Notify then Library:Notify("SUCCESS", "Sign Deleted!", 3) end
        task.delay(0.5, UpdateSoldSignButton)
    end)

    UpdateSoldSignButton()
    task.delay(2, UpdateSoldSignButton)

    Tab:CreateAction("Wipe Plot", "Wipe", function()
        local destroyRemote = interaction and interaction:FindFirstChild("DestroyStructure")
        if not playerModels or not destroyRemote then
            if Library and Library.Notify then Library:Notify("ERROR", "Wipe system unavailable", 3) end
            return
        end
        local toDestroy = {}
        for _, model in pairs(playerModels:GetChildren()) do
            local owner = model:FindFirstChild("Owner")
            if owner and owner.Value == LocalPlayer then
                local main = model:FindFirstChild("Main") or model:FindFirstChildWhichIsA("BasePart")
                if main then table.insert(toDestroy, { model = model, main = main }) end
            end
        end
        if #toDestroy == 0 then
            if Library and Library.Notify then Library:Notify("WIPE", "Nothing found to clear.", 3) end
            return
        end
        if Library and Library.Notify then
            Library:Notify("WIPE", "Clearing " .. #toDestroy .. " object(s)…", math.ceil(#toDestroy * 0.1))
        end
        local count = 0
        for _, entry in ipairs(toDestroy) do
            if not entry.model.Parent then continue end
            local timeout = 5
            local elapsed = 0
            while entry.model.Parent ~= nil and elapsed < timeout do
                pcall(destroyRemote.FireServer, destroyRemote, entry.model)
                task.wait(0.05)
                elapsed += 0.05
            end
            if entry.model.Parent == nil then
                count += 1
            else
                warn(("[Wipe] Timed out on '%s'."):format(entry.model.Name))
            end
        end
        if Library and Library.Notify then Library:Notify("SUCCESS", "Wiped " .. count .. " object(s).", 4) end
    end)
    
    -- ==========================================
    -- SIGN WATCHERS
    -- ==========================================
    if playerModels then
        playerModels.ChildAdded:Connect(function(child)
            task.defer(function()
                if not child.Parent then return end
                local settings = child:FindFirstChild("Settings")
                             or child:WaitForChild("Settings", 3)
                if settings and settings:FindFirstChild("PropertySoldSign") then
                    task.wait(0.2)
                    UpdateSoldSignButton()
                end
            end)
        end)
        playerModels.ChildRemoved:Connect(function()
            task.defer(UpdateSoldSignButton)
        end)
        playerModels.DescendantAdded:Connect(function(desc)
            if desc.Name == "PropertySoldSign" then task.defer(UpdateSoldSignButton) end
        end)
        playerModels.DescendantRemoving:Connect(function(desc)
            if desc.Name == "PropertySoldSign" then task.defer(UpdateSoldSignButton) end
        end)
    end

    -- ==========================================
    -- DYNAMIC LAND EVENT LISTENERS
    -- ==========================================
    if propertiesFolder then
        propertiesFolder.DescendantAdded:Connect(function(descendant)
            if descendant.Name == "Owner" and descendant:IsA("ObjectValue") then
                descendant.Changed:Connect(function() task.defer(UpdateLandButtons) end)
            end
            task.defer(UpdateLandButtons)
        end)
        propertiesFolder.DescendantRemoving:Connect(function()
            task.defer(UpdateLandButtons)
        end)
        for _, plot in pairs(propertiesFolder:GetChildren()) do
            local owner = plot:FindFirstChild("Owner")
            if owner and owner:IsA("ObjectValue") then
                owner.Changed:Connect(function() task.defer(UpdateLandButtons) end)
            end
        end
        UpdateLandButtons()
    end
end

return Plot
