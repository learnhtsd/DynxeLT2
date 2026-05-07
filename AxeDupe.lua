-- RespawnLoad.lua
local RespawnLoad = {}
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

function RespawnLoad.Init(Tab, Library)
    if not Tab then return warn("[RespawnLoad] Tab was nil!") end
    local LocalPlayer      = Players.LocalPlayer
    local loadSaveRequests = ReplicatedStorage:FindFirstChild("LoadSaveRequests")

    local function Notify(title, body, duration)
        if Library and Library.Notify then
            Library:Notify(title, body, duration or 4)
        else
            warn(("[RespawnLoad] %s — %s"):format(title, body))
        end
    end

    -- ================================================================
    --  CORE LOGIC
    -- ================================================================
    local function ReloadCurrentSlot()
        -- 1. Read active slot
        local slotObj = LocalPlayer:FindFirstChild("CurrentSaveSlot")
        if not slotObj or slotObj.Value == -1 then
            Notify("ERROR", "No save slot is currently loaded.", 5)
            return
        end
        local slot = slotObj.Value

        -- 2. Validate remotes
        if not loadSaveRequests then
            Notify("ERROR", "LoadSaveRequests folder not found.", 5)
            return
        end
        
        local RequestLoadRemote = loadSaveRequests:FindFirstChild("RequestLoad")
        local ClientMayLoad     = loadSaveRequests:FindFirstChild("ClientMayLoad")
        
        if not RequestLoadRemote or not ClientMayLoad then
            Notify("ERROR", "Necessary load remotes missing.", 5)
            return
        end

        -- 3. PRE-CHECK: Can we load right now?
        -- We invoke this BEFORE killing the player.
        local canLoad = false
        local success, result = pcall(function()
            return ClientMayLoad:InvokeServer(slot)
        end)

        if not success then
            Notify("ERROR", "ClientMayLoad failed to communicate.", 5)
            return
        elseif result ~= true then
            -- Usually returns false or a string reason if you are on cooldown
            Notify("DENIED", "Server denied load request (Cooldown?).", 5)
            return
        end

        -- 4. Character Validation
        local char     = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local hrp      = char and char:FindFirstChild("HumanoidRootPart")
        
        if not humanoid or humanoid.Health <= 0 then
            Notify("ERROR", "Character not found or already dead.", 5)
            return
        end

        Notify("RELOADING", "Permissions valid. Reloading slot " .. slot .. "…", 4)

        -- 5. Drop below the baseplate and wait until the humanoid is dead
        hrp.CFrame = CFrame.new(hrp.Position.X, -100, hrp.Position.Z)
        humanoid.Died:Wait()

        -- 6. Fire RequestLoad
        local ok, err = pcall(function()
            RequestLoadRemote:InvokeServer(slot)
        end)
        
        if not ok then
            Notify("FAILED", "RequestLoad failed: " .. tostring(err), 6)
            return
        end

        -- 7. Wait for the fresh character then confirm
        local newChar = LocalPlayer.CharacterAdded:Wait()
        newChar:WaitForChild("HumanoidRootPart", 10)
        Notify("SUCCESS", "Slot " .. slot .. " reloaded!", 5)
    end

    -- ================================================================
    --  UI
    -- ================================================================
    Tab:CreateSection("Axe Duplication")
    Tab:CreateAction("Inventory Axes", "Dupe", function()
        task.spawn(ReloadCurrentSlot)
    end)
end

return RespawnLoad
