local SettingsModule = {}
local CoreGui      = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
_G.NexusConnections = _G.NexusConnections or {}

function SettingsModule.Init(Tab, MainUI, RepoConfig, Config)
    local ScreenGui, MainFrame, SidebarFrame
    if typeof(MainUI) == "table" then
        ScreenGui    = MainUI.UI
        MainFrame    = MainUI.Frame
        SidebarFrame = MainUI.Sidebar
    elseif typeof(MainUI) == "Instance" then
        ScreenGui = MainUI
    end
    if not ScreenGui or not ScreenGui.Parent then
        ScreenGui = CoreGui:FindFirstChild("DynxeLT2Hub")
    end

    local W = Config and Config.Window

    -- ════════════════════════════════════════════════════════
    -- WINDOW SIZE
    -- ════════════════════════════════════════════════════════
    if Config and MainFrame then

        Tab:CreateSection("Customization")

        Tab:CreateSlider("Width", 300, 800, W.Width, function(val)
            W.Width = val
            TweenService:Create(MainFrame, TweenInfo.new(0.2), {
                Size = UDim2.new(0, val, 0, W.Height),
            }):Play()
        end)

        Tab:CreateSlider("Height", 150, 700, W.Height, function(val)
            W.Height = val
            TweenService:Create(MainFrame, TweenInfo.new(0.2), {
                Size = UDim2.new(0, W.Width, 0, val),
            }):Play()
        end)
        
        Tab:CreateSlider("Menu Opacity", 0, 100, 85, function(val)
            TweenService:Create(MainFrame, TweenInfo.new(0.2), {
                BackgroundTransparency = 1 - (val / 100)
            }):Play()
        end)
    end


    -- ════════════════════════════════════════════════════════
    -- SYSTEM
    -- ════════════════════════════════════════════════════════
    Tab:CreateSection("System")
    Tab:CreateKeybind("Toggle Menu", Enum.KeyCode.LeftAlt, function()
        if ScreenGui then
            ScreenGui.Enabled = not ScreenGui.Enabled
        end
    end)

    local function Unload()
        _G.NexusActive = false
        for _, conn in pairs(_G.NexusConnections) do
            if typeof(conn) == "RBXScriptConnection" and conn.Connected then
                conn:Disconnect()
            end
        end
        _G.NexusConnections = {}
        pcall(function() game:GetService("Lighting").ClockTime = 12 end)
        pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)
        if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end
    end

    local ReloadAction = Tab:CreateAction("Reload Script", "Reload", function()
        Unload()
        task.wait(0.1)
        local URL = string.format(
            "https://raw.githubusercontent.com/%s/%s/%s/main.lua?t=%s",
            RepoConfig.User, RepoConfig.Repo, RepoConfig.Branch, tick()
        )
        local ok, result = pcall(function() return game:HttpGet(URL) end)
        if ok and result and result ~= "" then
            local fn = loadstring(result)
            if fn then fn() else warn("[Settings] Reload: loadstring failed") end
        else
            warn("[Settings] Reload: HttpGet failed — " .. tostring(result))
        end
    end)
    ReloadAction:SetDisabled(true)

    local UnloadAction = Tab:CreateAction("Unload Script", "Unload", Unload)
    UnloadAction:SetDisabled(true)
end

return SettingsModule
