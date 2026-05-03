local TeleportModule = {}

function TeleportModule.Init(Tab)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    -- ===========================
    -- STATE VARIABLES
    -- ===========================
    local selectedTarget = nil
    local localTag = LocalPlayer.DisplayName .. " (You)"

    -- ===========================
    -- HELPERS
    -- ===========================
    local function GetPlayerList()
        local list = { localTag }
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(list, p.DisplayName)
            end
        end
        return list
    end

    local function Teleport(Pos)
        local Character = LocalPlayer.Character
        if Character and Character:FindFirstChild("HumanoidRootPart") then
            Character.HumanoidRootPart.CFrame = CFrame.new(Pos + Vector3.new(0, 5, 0))
        end
    end

    -- ===========================
    -- WORLD LOCATIONS (POIs)
    -- ===========================
    local poiData = {
        ["Wood R Us"]        = Vector3.new(265, 3, 57),
        ["Land Store"]       = Vector3.new(257, 3, -99),
        ["Boxed Cars"]       = Vector3.new(510, 3, -1465),
        ["Fancy Furnishings"]= Vector3.new(500, 3, -1720),
        ["Fine Arts Shop"]   = Vector3.new(5207, -166, 719),
        ["Links Logic"]      = Vector3.new(4607, 7, -795),
        ["Volcano"]          = Vector3.new(-1585, 622, 1140),
        ["Tiaga Peak"]       = Vector3.new(1448, 413, 3186),
        ["Swamp"]            = Vector3.new(-1209, 132, -801),
        ["Palm Island #1"]   = Vector3.new(2000, -6, -1500),
        ["Lonecave"]         = Vector3.new(3581, -179, 430),
        ["The Den"]          = Vector3.new(323.0, 41.8, 1930.0),
        ["Light House"]      = Vector3.new(1464.8, 355.2, 3257.2),
        ["Safari"]           = Vector3.new(111.9, 11.0, -998.8),
        ["Bridge"]           = Vector3.new(112.3, 11.0, -782.4),
        ["Bob's Shack"]      = Vector3.new(260.0, 8.4, -2542.0),
        ["The Cabin"]        = Vector3.new(1244.0, 63.6, 2306.0),
        ["SnowGlow Biome"]   = Vector3.new(-1087.3, -5.9, -946.2),
        ["Cave"]             = Vector3.new(3581.0, -179.5, 430.0),
        ["Shrine of Sight"]  = Vector3.new(-1600.0, 195.4, 919.0),
        ["Docks"]            = Vector3.new(1114.0, -1.2, -197.0),
        ["Strange Man"]      = Vector3.new(1061.0, 16.8, 1131.0),
        ["Snow Biome"]       = Vector3.new(890.0, 59.8, 1195.6),
        ["Green Box"]        = Vector3.new(-1668.1, 349.6, 1475.4),
        ["Cherry Meadow"]    = Vector3.new(220.9, 59.8, 1305.8),
        ["Bird Cave"]        = Vector3.new(4813.1, 17.7, -978.8),
    }

    local poiNames = {}
    for name in pairs(poiData) do table.insert(poiNames, name) end
    table.sort(poiNames)

    Tab:CreateSection("Point of Interest")

    Tab:CreateDropdown("Select Location", poiNames, "Select...", function(val)
        Teleport(poiData[val])
    end)

    -- ===========================
    -- PLAYER & PLOT SECTION
    -- ===========================
    Tab:CreateSection("Player & Plot Teleports")

    local tpBtn = Tab:CreateAction("Go to Player", "TP", function()
        if selectedTarget then
            for _, p in pairs(Players:GetPlayers()) do
                if p.DisplayName == selectedTarget and p.Character then
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then Teleport(hrp.Position) end
                end
            end
        end
    end)

    local plotBtn = Tab:CreateAction("Go to Player's Plot", "PLOT", function()
        -- Use selectedTarget if set, otherwise fall back to the local player
        local targetDisplay = selectedTarget or LocalPlayer.DisplayName
        local properties = workspace:FindFirstChild("Properties")
        if not properties then return end
        for _, plot in pairs(properties:GetChildren()) do
            local owner = plot:FindFirstChild("Owner")
            if owner and typeof(owner.Value) == "Instance"
                and owner.Value:IsA("Player")
                and owner.Value.DisplayName == targetDisplay then
                local origin = plot:FindFirstChild("OriginSquare")
                    or plot:FindFirstChild("Origin")
                    or plot:FindFirstChildOfClass("BasePart")
                if origin then Teleport(origin.Position) end
                break
            end
        end
    end)

    -- TP to self is pointless; plot button stays enabled so you can go to your own plot
    tpBtn:SetDisabled(true)

    local playerDropdown = Tab:CreateDropdown("Select Player", GetPlayerList(), "Select...", function(val)
        local isSelf = (val == localTag)
        selectedTarget = isSelf and nil or val
        tpBtn:SetDisabled(isSelf)
        -- plotBtn is never disabled — works for self and others alike
    end)

    -- ===========================
    -- PLAYER LIST REFRESH
    -- ===========================
    local function RefreshPlayerList()
        local list = GetPlayerList()
        playerDropdown:SetOptions(list)
        if selectedTarget then
            local stillPresent = false
            for _, name in ipairs(list) do
                if name == selectedTarget then stillPresent = true; break end
            end
            if not stillPresent then
                selectedTarget = nil
                tpBtn:SetDisabled(true)
            end
        end
    end

    Players.PlayerAdded:Connect(RefreshPlayerList)
    Players.PlayerRemoving:Connect(function()
        task.defer(RefreshPlayerList)
    end)
end

return TeleportModule
