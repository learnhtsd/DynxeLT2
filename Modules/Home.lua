local HomeModule = {}

function HomeModule.Init(Tab, Library)
    local Player          = game:GetService("Players").LocalPlayer
    local TeleportService = game:GetService("TeleportService")
    local HttpService     = game:GetService("HttpService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage") -- Added for Save Remote
    local Username        = Player.Name

    -- ── Helper: Force Save Logic ──────────────────────────────
    local function ForceSaveBeforeLeave()
        local loadSaveRequests = ReplicatedStorage:FindFirstChild("LoadSaveRequests")
        local currentSlot = Player:FindFirstChild("CurrentSaveSlot") 
                            or (Player:FindFirstChild("Data") and Player.Data:FindFirstChild("CurrentSaveSlot"))

        if loadSaveRequests and currentSlot and currentSlot.Value ~= -1 then
            local RequestSaveRemote = loadSaveRequests:FindFirstChild("RequestSave")
            if RequestSaveRemote then
                if Library and Library.Notify then 
                    Library:Notify("SYSTEM", "Saving plot before teleport...", 3) 
                end
                -- We use InvokeServer because it yields (waits) until the server confirms the save
                pcall(function()
                    RequestSaveRemote:InvokeServer(currentSlot.Value)
                end)
                task.wait(0.5) -- Small buffer to ensure data is processed
            end
        end
    end

    -- ── 1. Welcome InfoBox ────────────────────────────────────
    local WelcomeBox = Tab:CreateInfoBox()
    WelcomeBox:AddText("👋  Hello, " .. Username .. "!", {
        Bold  = true,
        Size  = 13,
        Color = Color3.fromRGB(220, 220, 220),
    })
    WelcomeBox:AddSpacer(2)
    WelcomeBox:AddText("Thank you for using Dynxe. You are currently using an early version. Im alone and need time :)", {
        Size   = 11,
        Color  = Color3.fromRGB(150, 150, 160),
        Wrap   = true,
        Italic = true,
    })
    WelcomeBox:AddSpacer(4)
    WelcomeBox:AddDivider()
    WelcomeBox:AddSpacer(2)
    WelcomeBox:AddText("⚠  EARLY ACCESS - EXPECT ISSUES :(", {
        Bold  = true,
        Size  = 10,
        Color = Color3.fromRGB(190, 130, 30),
    })

    -- ── 3. Server Management ──────────────────────────────────
    Tab:CreateSection("Server Management")

    local OneTimeScript = [[
        local ok, val = pcall(readfile, "dynxe_autoload.txt")
        if ok and val == "1" then
            pcall(writefile, "dynxe_autoload.txt", "0")
            loadstring(game:HttpGet("https://raw.githubusercontent.com/learnhtsd/lt2/main/main.lua?t=" .. tick()))()
        end
    ]]

    local function QueueOnce()
        if not queue_on_teleport then return end
        writefile("dynxe_autoload.txt", "1")
        queue_on_teleport(OneTimeScript)
    end

    local function ServerHop(order)
        ForceSaveBeforeLeave() -- SAVE TRIGGERED HERE
        QueueOnce()
        Library:Notify("System", "Searching for " .. (order == "Asc" and "smallest" or "largest") .. " server...", 4)
        local api = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=" .. order .. "&limit=100"
        local success, Servers = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(api))
        end)
        if success and Servers and Servers.data then
            for _, s in pairs(Servers.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, Player)
                    return
                end
            end
        end
        pcall(writefile, "dynxe_autoload.txt", "0")
        Library:Notify("Error", "No suitable server found.", 3)
    end

    Tab:CreateAction("Rejoin Server", "Rejoin", function()
        ForceSaveBeforeLeave() -- SAVE TRIGGERED HERE
        QueueOnce()
        TeleportService:Teleport(game.PlaceId, Player)
    end)

    local HopRow = Tab:CreateRow()
    HopRow:CreateAction("Descending", "Join", function() ServerHop("Asc")  end)
    HopRow:CreateAction("Ascending",  "Join", function() ServerHop("Desc") end)

    -- ── 4. Community & Support ────────────────────────────────
    Tab:CreateSection("Community & Support")

    Tab:CreateAction("Discord Server", "Copy", function()
        setclipboard("https://discord.gg/bSaWYeaw7Q")
        Library:Notify("System", "Discord link copied to clipboard!", 3)
    end)
end

return HomeModule
