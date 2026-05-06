local Duplication = {}

function Duplication.Init(Tab)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    
    -- ===========================
    -- STATE VARIABLES
    -- ===========================
    local env = getgenv and getgenv() or _G
    
    env.DupeSource = nil
    env.DupeTarget = nil
    
    -- Ensure connection table exists to prevent errors
    env.PM_Connections = env.PM_Connections or {}
    
    -- Item Toggles State
    env.DupeItems = {
        Furniture = false,
        Structures = false,
        Decorations = false,
        Plants = false
    }

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

    -- ===========================
    -- UI SECTIONS
    -- ===========================

    local Notice = Tab:CreateInfoBox()
    Notice:AddText("⚠ Tab Is Under Development", { Bold = true, Size = 14 })
    Notice:AddDivider()
    Notice:AddText("The Features Below Will Not Work", {
        Size    = 12,
        Opacity = 0.80,
        Italic  = true,
        Wrap    = true,
    })
    
    Tab:CreateSection("BASE DUPLICATION")

    -- Dropdowns: (Title, Options, Default, Callback)
    local SourceDropdown = Tab:CreateDropdown("Base To Duplicate:", GetPlayerNames(), "Select Owner", function(selected)
        env.DupeSource = selected
    end)

    local TargetDropdown = Tab:CreateDropdown("Base To Drop", GetPlayerNames(), "Select Target", function(selected)
        env.DupeTarget = selected
    end)

    -- Refresh Logic
    local function RefreshLists()
        local names = GetPlayerNames()
        -- Note: Documentation doesn't explicitly list :Refresh, 
        -- but if the library supports it, this will work.
        if SourceDropdown.Refresh then
            SourceDropdown:Refresh(names)
            TargetDropdown:Refresh(names)
        end
    end

    table.insert(env.PM_Connections, Players.PlayerAdded:Connect(RefreshLists))
    table.insert(env.PM_Connections, Players.PlayerRemoving:Connect(RefreshLists))

    local isProcessing = false
    -- Action: (Title, ButtonText, Callback, Secure)
    local StartButton = Tab:CreateAction("Duplicate", "Start", function()
        if isProcessing then return end 
        
        if not env.DupeSource or not env.DupeTarget then
            warn("Please select a Source and Target first!")
            return
        end

        isProcessing = true
        StartButton:SetText("Processing...") 
        
        print("Executing Dupe from", env.DupeSource, "to", env.DupeTarget)

        -- Simulating the process
        task.delay(5, function()
            isProcessing = false
            StartButton:SetText("Start Duplication")
            print("Duplication sequence finished.")
        end)
    end)
  
    ---
    Tab:CreateSection("OBJECTS TO DUPLICATE")

    -- Toggles: (Title, Default, Callback)
    Tab:CreateToggle("Structures & Blueprints", false, function(s) env.DupeItems.Structures = s end)
    Tab:CreateToggle("Furniture", false, function(s) env.DupeItems.Furniture = s end)
    Tab:CreateToggle("Wires", false, function(s) env.DupeItems.Decorations = s end)
    Tab:CreateToggle("Gifts", false, function(s) env.DupeItems.Decorations = s end)
    Tab:CreateToggle("Axes", false, function(s) env.DupeItems.Decorations = s end)
    Tab:CreateToggle("Planks/Wood", false, function(s) env.DupeItems.Decorations = s end)

end

return Duplication
