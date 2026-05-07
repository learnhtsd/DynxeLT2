local GhostSuite = {}

function GhostSuite.Init(Tab)
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()

    -- ===========================
    -- STATE & CONFIG
    -- ===========================
    _G.GhostSuiteEnabled = false
    _G.GhostFullModel = false -- New Toggle State
    _G.GhostUseBlacklist = true -- Blacklist on by default
    local ExtractedObjects = {}
    
    local BlacklistNames = {
        ["Baseplate"] = true, ["BasePlate"] = true,
        ["Ground"] = true, ["Water"] = true, ["Map"] = true
    }

    -- ===========================
    -- CORE LOGIC
    -- ===========================
    local function IsProtected(target)
        if not target then return true end
        if BlacklistNames[target.Name] then return true end
        if target:FindFirstAncestor("Properties") or target:FindFirstAncestor("Owner") then
            return true
        end
        if target.Name:lower():find("baseplate") then return true end
        return false
    end

    local function CreateOutline(target)
        local box = Instance.new("SelectionBox")
        box.Name = "GhostHighlighter"
        box.Adornee = target
        box.LineThickness = 0.05
        box.Color3 = Color3.fromRGB(0, 255, 150)
        box.SurfaceColor3 = Color3.fromRGB(0, 255, 150)
        box.SurfaceTransparency = 0.8
        box.Parent = game:GetService("CoreGui") 
        return box
    end

    -- Helper to ghost a single part
    local function GhostPart(part)
        if not part:IsA("BasePart") or IsProtected(part) then return end
        if not ExtractedObjects[part] then
            local originalParent = part.Parent
            local outline = CreateOutline(part)
            ExtractedObjects[part] = { Parent = originalParent, Box = outline }
            part.Parent = nil
        end
    end

    -- Helper to restore a single part
    local function RestorePart(part)
        local data = ExtractedObjects[part]
        if data then
            part.Parent = data.Parent
            if data.Box then data.Box:Destroy() end
            ExtractedObjects[part] = nil
        end
    end

    local function RestoreAll()
        local count = 0
        for part, data in pairs(ExtractedObjects) do
            if part then
                part.Parent = data.Parent
                if data.Box then data.Box:Destroy() end
                count = count + 1
            end
        end
        ExtractedObjects = {}
        return count
    end

    local function IsProtected(target)
        if not target then return true end
        if _G.GhostUseBlacklist then
            if BlacklistNames[target.Name] then return true end
            if target:FindFirstAncestor("Properties") or target:FindFirstAncestor("Owner") then
                return true
            end
            if target.Name:lower():find("baseplate") then return true end
        end
        return false
    end

    -- ===========================
    -- UI ELEMENTS
    -- ===========================
    Tab:CreateSection("Ghost Suite")
    
    Tab:CreateToggle("Master Enable", false, function(s) 
        _G.GhostSuiteEnabled = s 
        if not s then RestoreAll() end
    end)

    Tab:CreateToggle("Ghost Full Model", false, function(s) 
        _G.GhostFullModel = s 
    end)
    
    Tab:CreateToggle("Protect Baseplate & Map", true, function(s)
        _G.GhostUseBlacklist = s
    end)

    Tab:CreateAction("Restore All Objects", "Reset", function()
        local count = RestoreAll()
        print("Restored " .. count .. " objects.")
    end)

    Tab:CreateKeybind("Ghost Object Key", Enum.UserInputType.MouseButton3, function()
        if not _G.GhostSuiteEnabled then return end
        
        local target = Mouse.Target
        if not target or not target:IsA("BasePart") then return end
        if IsProtected(target) then return end

        -- If full model mode is on, find the parent model
        local root = target
        if _G.GhostFullModel then
            local model = target:FindFirstAncestorOfClass("Model") or target:FindFirstAncestorOfClass("Folder")
            if model and model ~= workspace then
                root = model
            end
        end

        -- Toggle Logic
        if root:IsA("BasePart") then
            if ExtractedObjects[root] then RestorePart(root) else GhostPart(root) end
        else
            -- If it's a Model/Folder, check if the first part we find is ghosted to decide on toggle direction
            local firstPart = root:FindFirstChildWhichIsA("BasePart", true)
            local shouldRestore = firstPart and ExtractedObjects[firstPart]

            for _, descendant in pairs(root:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    if shouldRestore then RestorePart(descendant) else GhostPart(descendant) end
                end
            end
        end
    end)

    Tab:CreateKeybind("Mass Restore Key", Enum.KeyCode.Z, function()
        if not _G.GhostSuiteEnabled then return end
        RestoreAll()
    end)
end

return GhostSuite
