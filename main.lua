local User = "learnhtsd"
local Repo = "DynxeLT2"
local Branch = "main"
local Version = "v2"

task.spawn(function()
    local ICON_FOLDER  = "DynxeLT2"
    local VERSION_FILE = ICON_FOLDER .. "/_version"

    if not (isfolder and listfiles and isfile and delfile and writefile) then return end

    -- Read whatever version is stamped inside the folder
    local storedOk, storedVersion = pcall(readfile, VERSION_FILE)
    local upToDate = storedOk and storedVersion == Version

    if not upToDate then
        -- Wipe every cached asset in the folder
        if isfolder(ICON_FOLDER) then
            local ok, files = pcall(listfiles, ICON_FOLDER)
            if ok and type(files) == "table" then
                for _, path in ipairs(files) do
                    if path:match("%.png$") then
                        pcall(delfile, path)
                    end
                end
            end
        else
            makefolder(ICON_FOLDER)
        end

        -- Stamp the new version
        pcall(writefile, VERSION_FILE, Version)
    end
end)

--loadstring(game:HttpGet("https://raw.githubusercontent.com/learnhtsd/lt2/refs/heads/main/main.lua"))()

-- ██████╗  ██████╗ ███╗   ██╗███████╗██╗ ██████╗
-- ██╔════╝ ██╔═══██╗████╗  ██║██╔════╝██║██╔════╝
-- ██║      ██║   ██║██╔██╗ ██║█████╗  ██║██║  ███╗
-- ██║      ██║   ██║██║╚██╗██║██╔══╝  ██║██║   ██║
-- ╚██████╗ ╚██████╔╝██║ ╚████║██║     ██║╚██████╔╝
--  ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝

local Config = {
    Window = { -- Menu Scale
        Width  = 420,
        Height = 540,
        SidebarWidth = 40,
    },
    Elements = { -- UI Element Scale
        Scale = 0.80,
    },
    Theme = { -- Theme Color Pallet
        Accent          = Color3.fromRGB(74,  120, 255),  -- blue highlights / active
        Background      = Color3.fromRGB(18,  18,  22),   -- main window background
        Surface         = Color3.fromRGB(24,  24,  29),   -- element cards / dropdowns
        SurfaceDeep     = Color3.fromRGB(35,  35,  42),   -- inset areas / track bg
        Sidebar         = Color3.fromRGB(14,  14,  17),   -- sidebar background
        Stroke          = Color3.fromRGB(40,  40,  48),   -- border / depth strokes
        TextPrimary     = Color3.fromRGB(220, 220, 220),  -- element title text
        TextSecondary   = Color3.fromRGB(120, 120, 130),  -- muted / icon text
        TextDark        = Color3.fromRGB(180, 180, 180),  -- description text
        TextWhite       = Color3.fromRGB(255, 255, 255),  -- header / active labels
        Success         = Color3.fromRGB(45,  160, 75),   -- confirm-action green
        Warning         = Color3.fromRGB(190, 120, 15),   -- secure-action amber
        NotifBackground = Color3.fromRGB(24,  24,  29),   -- notification card bg
    },
}

-- ============================================================
-- SCALE HELPERS  (do not edit — derived from Config above)
-- ES()  = Element Scale  — use for heights, padding, offsets
-- FS()  = Font Scale     — clamped so text never becomes unreadable
-- ============================================================
local function ES(n) return math.round(n * Config.Elements.Scale) end
local function FS(n) return math.max(8, math.round(n * Config.Elements.Scale)) end
local T = Config.Theme   -- shorthand: T.Accent, T.Surface, etc.
local W = Config.Window  -- shorthand: W.Width, W.Height, etc.

-- ============================================================
-- UI ENGINE
-- ============================================================
local Library = {}
local CoreGui          = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

for _, v in pairs(CoreGui:GetChildren()) do
    if v.Name == "DynxeLT2Hub" then v:Destroy() end
    if v.Name == "DynxeLT2Notifications" then v:Destroy() end
end

-- ── Image helper (unchanged) ─────────────────────────────────
-- Reliable cross-executor existence check. isfile() returns false in Xeno
-- even for real files; pcall(readfile) succeeds iff the file truly exists.
local function FileExists(path)
    local ok, data = pcall(readfile, path)
    return ok and type(data) == "string" and #data > 0
end

getgenv().GetImage = function(folder, fileName)
    local base       = "DynxeLT2"
    local localPath  = (folder ~= "" and folder ~= nil)
                       and (base .. "/" .. folder .. "/" .. fileName)
                       or  (base .. "/" .. fileName)
    local folderPath = (folder ~= "" and folder ~= nil)
                       and (base .. "/" .. folder)
                       or  base
    local placeholderLocal = base .. "/Placeholder.png"
    local placeholderUrl   = string.format(
        "https://raw.githubusercontent.com/%s/%s/%s/Images/Placeholder.png",
        User, Repo, Branch
    )
    if isfolder and not isfolder(base)       then makefolder(base)       end
    if isfolder and not isfolder(folderPath) then makefolder(folderPath) end
    if not FileExists(placeholderLocal) then
        local pOk, pData = pcall(function() return game:HttpGet(placeholderUrl) end)
        if pOk and #pData > 100 then writefile(placeholderLocal, pData) end
    end
    if FileExists(localPath) then return getcustomasset(localPath) end
    local url = string.format(
        "https://raw.githubusercontent.com/%s/%s/%s/Images/%s/%s",
        User, Repo, Branch, folder, fileName
    )
    local ok, content = pcall(function() return game:HttpGet(url) end)
    if ok and content and not content:find("404: Not Found") and #content > 100 then
        writefile(localPath, content)
        return getcustomasset(localPath)
    else
        warn("Asset Missing: " .. fileName)
        return FileExists(placeholderLocal) and getcustomasset(placeholderLocal) or "rbxassetid://6023426923"
    end
end

-- ── Window ───────────────────────────────────────────────────
function Library:CreateWindow()
    local Window     = {}
    local CurrentTab = nil

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name            = "DynxeLT2Hub"
    ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent          = CoreGui

    -- TOOLTIP
    local TooltipGui = Instance.new("TextLabel")
    TooltipGui.Size                = UDim2.new(0, 0, 0, 0)
    TooltipGui.AutomaticSize       = Enum.AutomaticSize.XY
    TooltipGui.BackgroundColor3    = Color3.fromRGB(20, 20, 25)
    TooltipGui.TextColor3          = T.TextDark
    TooltipGui.Font                = Enum.Font.GothamMedium
    TooltipGui.TextSize            = FS(11)
    TooltipGui.RichText            = true
    TooltipGui.Visible             = false
    TooltipGui.ZIndex              = 100
    TooltipGui.Parent              = ScreenGui
    local TTPad = Instance.new("UIPadding", TooltipGui)
    TTPad.PaddingTop    = UDim.new(0, ES(6))
    TTPad.PaddingBottom = UDim.new(0, ES(6))
    TTPad.PaddingLeft   = UDim.new(0, ES(8))
    TTPad.PaddingRight  = UDim.new(0, ES(8))
    Instance.new("UICorner", TooltipGui).CornerRadius = UDim.new(0, 4)
    local TTStroke = Instance.new("UIStroke", TooltipGui)
    TTStroke.Color     = Color3.fromRGB(150, 150, 150)
    TTStroke.Thickness = 1

    function Library.ShowTooltip(text)
        TooltipGui.Text    = text
        TooltipGui.Visible = true
    end
    function Library.HideTooltip()
        TooltipGui.Visible = false
    end
    UserInputService.InputChanged:Connect(function(input)
        if TooltipGui.Visible and input.UserInputType == Enum.UserInputType.MouseMovement then
            TooltipGui.Position = UDim2.new(0, math.round(input.Position.X + 12), 0, math.round(input.Position.Y + 12))
        end
    end)

    -- TOOLTIP ATTACHMENT HELPER
    local function AttachTooltip(TitleLabel, ElementTable)
        function ElementTable:AddTooltip(text)
            local InfoIcon = Instance.new("TextLabel")
            InfoIcon.Size               = UDim2.new(0, ES(16), 0, ES(16))
            InfoIcon.AnchorPoint        = Vector2.new(0, 0.5)
            InfoIcon.BackgroundTransparency = 1
            InfoIcon.Text               = "(?)"
            InfoIcon.TextColor3         = T.TextSecondary
            InfoIcon.Font               = Enum.Font.Gotham
            InfoIcon.TextSize           = FS(11)
            InfoIcon.Parent             = TitleLabel
            local function updatePos()
                InfoIcon.Position = UDim2.new(0, TitleLabel.TextBounds.X + 6, 0.5, 0)
            end
            TitleLabel:GetPropertyChangedSignal("TextBounds"):Connect(updatePos)
            updatePos()
            InfoIcon.MouseEnter:Connect(function()
                InfoIcon.TextColor3 = T.Accent
                Library.ShowTooltip(text)
            end)
            InfoIcon.MouseLeave:Connect(function()
                InfoIcon.TextColor3 = T.TextSecondary
                Library.HideTooltip()
            end)
            return ElementTable
        end
        return ElementTable
    end

    -- MAIN FRAME
    local MainFrame = Instance.new("Frame")
    MainFrame.Size                 = UDim2.new(0, W.Width, 0, W.Height)
    MainFrame.Position             = UDim2.new(0, 0, 1, -(W.Height + 120))
    MainFrame.BackgroundColor3     = T.Background
    MainFrame.BackgroundTransparency = 0.15
    MainFrame.BorderSizePixel      = 0
    MainFrame.ZIndex               = 2
    MainFrame.Parent               = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)

    -- SIDEBAR
    local Sidebar = Instance.new("Frame")
    Sidebar.Size             = UDim2.new(0, W.SidebarWidth, 1, 0)
    Sidebar.BackgroundColor3 = T.Sidebar
    Sidebar.BorderSizePixel  = 0
    Sidebar.Parent           = MainFrame
    Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 6)

    local SideBlock = Instance.new("Frame")
    SideBlock.Size             = UDim2.new(0, 10, 1, 0)
    SideBlock.Position         = UDim2.new(1, -10, 0, 0)
    SideBlock.BackgroundColor3 = T.Sidebar
    SideBlock.BorderSizePixel  = 0
    SideBlock.Parent           = Sidebar

    -- HEADER
    local HeaderTitle = Instance.new("TextLabel")
    HeaderTitle.Size               = UDim2.new(1, -(W.SidebarWidth + 25), 0, 30)
    HeaderTitle.Position           = UDim2.new(0, W.SidebarWidth + 15, 0, 10)
    HeaderTitle.BackgroundTransparency = 1
    HeaderTitle.Text               = "<b>Dynxe</b> <font color=\"#4a78ff\">LT2</font> <font color=\"#555555\" size=\"" .. FS(12) .. "\">" .. Version .. "</font>"
    HeaderTitle.RichText           = true
    HeaderTitle.TextColor3         = T.TextWhite
    HeaderTitle.Font               = Enum.Font.GothamMedium
    HeaderTitle.TextSize           = FS(16)
    HeaderTitle.TextXAlignment     = Enum.TextXAlignment.Left
    HeaderTitle.Parent             = MainFrame

    local ActiveTabLabel = Instance.new("TextLabel")
    ActiveTabLabel.Size            = UDim2.new(0, 150, 0, 30)
    ActiveTabLabel.Position        = UDim2.new(1, -165, 0, 10)
    ActiveTabLabel.BackgroundTransparency = 1
    ActiveTabLabel.Text            = ""
    ActiveTabLabel.TextColor3      = T.Accent
    ActiveTabLabel.Font            = Enum.Font.GothamMedium
    ActiveTabLabel.TextSize        = FS(12)
    ActiveTabLabel.TextXAlignment  = Enum.TextXAlignment.Right
    ActiveTabLabel.Parent          = MainFrame
    
    -- TAB CONTAINER (inside sidebar)
    local TabContainer = Instance.new("ScrollingFrame")
    TabContainer.Name              = "TabContainer"
    TabContainer.Size              = UDim2.new(1, 0, 1, 0)
    TabContainer.BackgroundTransparency = 1
    TabContainer.ScrollBarThickness = 0
    TabContainer.BorderSizePixel   = 0
    TabContainer.ScrollingDirection = Enum.ScrollingDirection.Y
    TabContainer.Parent            = Sidebar

    local SidebarList = Instance.new("UIListLayout")
    SidebarList.Parent             = TabContainer
    SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    SidebarList.VerticalAlignment  = Enum.VerticalAlignment.Top
    SidebarList.SortOrder          = Enum.SortOrder.LayoutOrder
    SidebarList.Padding            = UDim.new(0, ES(15))

    local SidebarPadding = Instance.new("UIPadding")
    SidebarPadding.Parent     = TabContainer
    SidebarPadding.PaddingTop = UDim.new(0, ES(20))

    SidebarList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabContainer.CanvasSize = UDim2.new(0, 0, 0, SidebarList.AbsoluteContentSize.Y + 30)
    end)

    -- CONTENT AREA
    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size              = UDim2.new(1, -(W.SidebarWidth + 30), 1, -60)
    ContentContainer.Position          = UDim2.new(0, W.SidebarWidth + 15, 0, 45)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.ClipsDescendants  = true
    ContentContainer.Parent            = MainFrame

    -- NOTIFICATIONS
    local NotifGui = Instance.new("ScreenGui")
    NotifGui.Name            = "DynxeLT2Notifications"
    NotifGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    NotifGui.DisplayOrder    = 999   -- always renders above everything
    NotifGui.ResetOnSpawn    = false
    NotifGui.Parent          = CoreGui
    
    local NotificationContainer = Instance.new("Frame")
    NotificationContainer.Name                   = "NotificationContainer"
    NotificationContainer.Size                   = UDim2.new(0, 250, 1, -20)
    NotificationContainer.Position               = UDim2.new(1, -260, 0, 10)
    NotificationContainer.BackgroundTransparency = 1
    NotificationContainer.Parent                 = NotifGui

    local NotifList = Instance.new("UIListLayout")
    NotifList.Parent           = NotificationContainer
    NotifList.VerticalAlignment = Enum.VerticalAlignment.Bottom
    NotifList.SortOrder        = Enum.SortOrder.LayoutOrder
    NotifList.Padding          = UDim.new(0, 8)

    function Library:Notify(Title, Text, Duration)
        Duration = Duration or 5
        local NotifFrame = Instance.new("Frame")
        NotifFrame.Size             = UDim2.new(1, 0, 0, 0)
        NotifFrame.BackgroundColor3 = T.NotifBackground
        NotifFrame.BackgroundTransparency = 0.2
        NotifFrame.BorderSizePixel  = 0
        NotifFrame.ClipsDescendants = true
        NotifFrame.Parent           = NotificationContainer
        Instance.new("UICorner", NotifFrame).CornerRadius = UDim.new(0, 6)
        local Stroke = Instance.new("UIStroke", NotifFrame)
        Stroke.Color     = T.Accent
        Stroke.Thickness = 1
        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Size            = UDim2.new(1, -20, 0, ES(20))
        TitleLabel.Position        = UDim2.new(0, 10, 0, 5)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Text            = Title:upper()
        TitleLabel.TextColor3      = T.Accent
        TitleLabel.Font            = Enum.Font.GothamBold
        TitleLabel.TextSize        = FS(12)
        TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
        TitleLabel.Parent          = NotifFrame
        local ContentLabel = Instance.new("TextLabel")
        ContentLabel.Size          = UDim2.new(1, -20, 0, ES(30))
        ContentLabel.Position      = UDim2.new(0, 10, 0, ES(22))
        ContentLabel.BackgroundTransparency = 1
        ContentLabel.Text          = Text
        ContentLabel.TextColor3    = T.TextDark
        ContentLabel.Font          = Enum.Font.Gotham
        ContentLabel.TextSize      = FS(11)
        ContentLabel.TextWrapped   = true
        ContentLabel.TextXAlignment = Enum.TextXAlignment.Left
        ContentLabel.Parent        = NotifFrame
        TweenService:Create(NotifFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, ES(60))}):Play()
        task.delay(Duration, function()
            local Tween = TweenService:Create(NotifFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1})
            Tween:Play()
            Tween.Completed:Connect(function() NotifFrame:Destroy() end)
        end)
    end

    -- DRAG
    local dragging, dragStart, startPos = false, nil, nil
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        end
    end)
    MainFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local d = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    -- ── CREATE TAB ───────────────────────────────────────────
    function Window:CreateTab(TabName)
        local Tab = {}

        -- Tab icon button in sidebar
        local TabBtn = Instance.new("ImageButton")
        TabBtn.Name              = TabName
        TabBtn.Size              = UDim2.new(0, ES(32), 0, ES(32))
        TabBtn.Parent            = TabContainer
        TabBtn.BackgroundColor3  = T.Accent
        TabBtn.BackgroundTransparency = 1
        Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 8)

        local FallbackText = Instance.new("TextLabel", TabBtn)
        FallbackText.Size              = UDim2.new(1, 0, 1, 0)
        FallbackText.BackgroundTransparency = 1
        FallbackText.Text              = string.sub(TabName, 1, 1):upper()
        FallbackText.TextColor3        = T.TextSecondary
        FallbackText.Font              = Enum.Font.GothamBold
        FallbackText.TextSize          = FS(14)
        FallbackText.Name              = "TabIconText"

        -- icon download (unchanged logic)
        local folderName  = "DynxeLT2"
        local fileName    = TabName .. ".png"          -- no version stamp; marker handles invalidation
        local filePath    = folderName .. "/" .. fileName
        local finalAssetUrl = ""
        if isfolder and makefolder and writefile and isfile and getcustomasset then
            if not isfolder(folderName) then makefolder(folderName) end
            if not FileExists(filePath) then
                local iconUrl = string.format("https://raw.githubusercontent.com/%s/%s/%s/Icons/%s.png?t=%s", User, Repo, Branch, TabName, tick())
                local ok, imgData = pcall(function() return game:HttpGet(iconUrl) end)
                if ok and imgData and not imgData:match("404: Not Found") then writefile(filePath, imgData) end
            end
            if FileExists(filePath) then finalAssetUrl = getcustomasset(filePath) end
        end

        local TabIcon = Instance.new("ImageLabel")
        TabIcon.Size               = UDim2.new(0, ES(20), 0, ES(20))
        TabIcon.Position           = UDim2.new(0.5, -ES(10), 0.5, -ES(10))
        TabIcon.BackgroundTransparency = 1
        TabIcon.Image              = finalAssetUrl
        TabIcon.ImageColor3        = T.TextWhite
        TabIcon.ScaleType          = Enum.ScaleType.Fit
        TabIcon.Name               = "TabIcon"
        TabIcon.Parent             = TabBtn
        if finalAssetUrl ~= "" then FallbackText.Visible = false end

        local TweenIn  = TweenService:Create(TabBtn, TweenInfo.new(0.3), {BackgroundTransparency = 0.85})
        local TweenOut = TweenService:Create(TabBtn, TweenInfo.new(0.3), {BackgroundTransparency = 1})

        -- Tab page (scrolling content)
        local TabPage = Instance.new("ScrollingFrame")
        TabPage.Size               = UDim2.new(1, 0, 1, 0)
        TabPage.BackgroundTransparency = 1
        TabPage.ScrollBarThickness = 0
        TabPage.BorderSizePixel    = 0
        TabPage.Visible            = false
        TabPage.ClipsDescendants   = true
        TabPage.Parent             = ContentContainer
        Tab.Container              = TabPage

        local PageLayout = Instance.new("UIListLayout")
        PageLayout.Parent   = TabPage
        PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        PageLayout.Padding  = UDim.new(0, ES(6))

        local PagePadding = Instance.new("UIPadding")
        PagePadding.Parent        = TabPage
        PagePadding.PaddingLeft   = UDim.new(0, 2)
        PagePadding.PaddingRight  = UDim.new(0, 8)
        PagePadding.PaddingTop    = UDim.new(0, 2)
        PagePadding.PaddingBottom = UDim.new(0, ES(20))

        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TabPage.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 25)
        end)

        local function ActivateTab()
            if CurrentTab then
                CurrentTab.TweenOut:Play()
                CurrentTab.Btn.TabIconText.TextColor3 = T.TextSecondary
                local prev = CurrentTab.Btn:FindFirstChild("TabIcon")
                if prev then prev.ImageColor3 = T.TextSecondary end
                CurrentTab.Page.Visible = false
            end
            TweenIn:Play()
            FallbackText.TextColor3 = T.TextWhite
            TabIcon.ImageColor3     = T.TextWhite
            TabPage.Visible         = true
            ActiveTabLabel.Text     = TabName:upper()
            CurrentTab = {Btn = TabBtn, TweenOut = TweenOut, Page = TabPage}
        end

        TabBtn.MouseButton1Click:Connect(ActivateTab)
        if not CurrentTab then ActivateTab() end

        -- ── SHARED HELPERS ────────────────────────────────────
        local function AddDepthStroke(frame)
            local Stroke = Instance.new("UIStroke")
            Stroke.Parent          = frame
            Stroke.Color           = T.Stroke
            Stroke.Thickness       = 1
            Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        end

        -- ── ROW ───────────────────────────────────────────────
        function Tab:CreateRow()
            local Row = setmetatable({}, {__index = self})
            local RowFrame = Instance.new("Frame")
            RowFrame.Size              = UDim2.new(1, 0, 0, ES(28))
            RowFrame.BackgroundTransparency = 1
            RowFrame.Parent            = self.Container
            local RowLayout = Instance.new("UIListLayout")
            RowLayout.Parent          = RowFrame
            RowLayout.FillDirection   = Enum.FillDirection.Horizontal
            RowLayout.SortOrder       = Enum.SortOrder.LayoutOrder
            RowLayout.Padding         = UDim.new(0, ES(6))
            RowLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                RowFrame.Size = UDim2.new(1, 0, 0, RowLayout.AbsoluteContentSize.Y)
            end)
            RowFrame.ChildAdded:Connect(function()
                task.defer(function()
                    local elements = {}
                    for _, v in pairs(RowFrame:GetChildren()) do
                        if v:IsA("GuiObject") and not v:IsA("UIListLayout") then
                            table.insert(elements, v)
                        end
                    end
                    local count = #elements
                    if count > 0 then
                        local totalPadding = (count - 1) * ES(6)
                        for _, v in pairs(elements) do
                            v.Size = UDim2.new(1/count, -totalPadding/count, 0, v.Size.Y.Offset)
                        end
                    end
                end)
            end)
            Row.Container = RowFrame
            return Row
        end

        -- ── SECTION ───────────────────────────────────────────
        function Tab:CreateSection(Name)
            local SectionLabel = Instance.new("TextLabel")
            SectionLabel.Size              = UDim2.new(1, 0, 0, ES(20))
            SectionLabel.BackgroundTransparency = 1
            SectionLabel.Text              = Name:upper()
            SectionLabel.TextColor3        = T.Accent
            SectionLabel.Font              = Enum.Font.GothamBold
            SectionLabel.TextSize          = FS(11)
            SectionLabel.TextXAlignment    = Enum.TextXAlignment.Left
            SectionLabel.Parent            = self.Container
        end

        -- ── ACTION ────────────────────────────────────────────
        function Tab:CreateAction(Title, ButtonText, Callback, Secure)
            local Element     = {}
            Element.Disabled  = false -- Track disabled state
            
            local RowHeight   = ES(28)
            local BtnHeight   = ES(20)
            local BtnWidth    = ES(70)
        
            local ActionFrame = Instance.new("Frame")
            ActionFrame.Size             = UDim2.new(1, 0, 0, RowHeight)
            ActionFrame.BackgroundColor3 = T.Surface
            ActionFrame.Parent           = self.Container
            Instance.new("UICorner", ActionFrame).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(ActionFrame)
        
            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size            = UDim2.new(0.65, 0, 1, 0)
            TitleLabel.Position        = UDim2.new(0, ES(10), 0, 0)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text            = Title
            TitleLabel.TextColor3      = T.TextPrimary
            TitleLabel.Font            = Enum.Font.GothamMedium
            TitleLabel.TextSize        = FS(12)
            TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
            TitleLabel.Parent          = ActionFrame
        
            if Secure then
                local LockBadge = Instance.new("TextLabel")
                LockBadge.Size             = UDim2.new(0, ES(22), 0, ES(14))
                LockBadge.AnchorPoint      = Vector2.new(0, 0.5)
                LockBadge.BackgroundColor3 = Color3.fromRGB(180, 120, 20)
                LockBadge.BackgroundTransparency = 0.3
                LockBadge.Text             = "🔒"
                LockBadge.TextSize         = FS(9)
                LockBadge.Font             = Enum.Font.Gotham
                LockBadge.TextColor3       = Color3.fromRGB(255, 220, 100)
                LockBadge.Parent           = TitleLabel
                Instance.new("UICorner", LockBadge).CornerRadius = UDim.new(0, 3)
                local function updateBadgePos()
                    LockBadge.Position = UDim2.new(0, TitleLabel.TextBounds.X + 8, 0.5, 0)
                end
                TitleLabel:GetPropertyChangedSignal("TextBounds"):Connect(updateBadgePos)
                updateBadgePos()
            end
        
            local ActionBtn = Instance.new("TextButton")
            ActionBtn.Size             = UDim2.new(0, BtnWidth, 0, BtnHeight)
            ActionBtn.AnchorPoint      = Vector2.new(1, 0.5)
            ActionBtn.Position         = UDim2.new(1, -ES(8), 0.5, 0)
            ActionBtn.BackgroundColor3 = T.SurfaceDeep
            ActionBtn.Text             = ButtonText
            ActionBtn.TextColor3       = T.TextWhite
            ActionBtn.Font             = Enum.Font.GothamBold
            ActionBtn.TextSize         = FS(11)
            ActionBtn.Parent           = ActionFrame
            Instance.new("UICorner", ActionBtn).CornerRadius = UDim.new(0, 4)
            AddDepthStroke(ActionBtn)
        
            -- INTERNAL STATE HELPERS
            local awaitingConfirm = false
            local resetThread     = nil
        
            local function resetBtn()
                awaitingConfirm = false
                TweenService:Create(ActionBtn, TweenInfo.new(0.25), {
                    BackgroundColor3 = Element.Disabled and T.Surface or T.SurfaceDeep,
                    TextTransparency = Element.Disabled and 0.5 or 0
                }):Play()
                ActionBtn.Text      = ButtonText
                ActionBtn.TextColor3 = T.TextWhite
            end
        
            -- PUBLIC METHODS
            function Element:SetText(NewText)
                ButtonText = NewText
                if not awaitingConfirm then
                    ActionBtn.Text = NewText
                end
            end
        
            function Element:SetDisabled(State)
                Element.Disabled = State
                ActionBtn.Active = not State
                
                -- Visual feedback for disabled state
                TweenService:Create(ActionBtn, TweenInfo.new(0.2), {
                    BackgroundTransparency = State and 0.5 or 0,
                    TextTransparency = State and 0.5 or 0,
                    BackgroundColor3 = State and T.Surface or T.SurfaceDeep
                }):Play()
        
                -- Cancel any active confirmation if we disable it mid-process
                if State and awaitingConfirm then
                    if resetThread then task.cancel(resetThread) end
                    resetBtn()
                end
            end
        
            -- CLICK LOGIC
            ActionBtn.MouseButton1Click:Connect(function()
                if Element.Disabled then return end
                
                if Secure then
                    if not awaitingConfirm then
                        awaitingConfirm = true
                        TweenService:Create(ActionBtn, TweenInfo.new(0.2), {BackgroundColor3 = T.Warning}):Play()
                        ActionBtn.Text      = "Confirm?"
                        ActionBtn.TextColor3 = Color3.fromRGB(255, 240, 180)
                        if resetThread then task.cancel(resetThread) end
                        resetThread = task.delay(3, resetBtn)
                    else
                        if resetThread then task.cancel(resetThread) end
                        awaitingConfirm = false
                        TweenService:Create(ActionBtn, TweenInfo.new(0.15), {BackgroundColor3 = T.Success}):Play()
                        ActionBtn.Text      = "✓ Done"
                        ActionBtn.TextColor3 = Color3.fromRGB(200, 255, 210)
                        Callback()
                        task.delay(1.2, resetBtn)
                    end
                else
                    Callback()
                end
            end)
        
            return AttachTooltip(TitleLabel, Element)
        end

        -- ── TOGGLE ────────────────────────────────────────────────────────────
        function Tab:CreateToggle(Title, Default, Callback)
            local Element        = {}
            local Toggled        = Default
            local toggleDisabled = false
            local RowHeight      = ES(28)
        
            local ToggleFrame = Instance.new("Frame")
            ToggleFrame.Size             = UDim2.new(1, 0, 0, RowHeight)
            ToggleFrame.BackgroundColor3 = T.Surface
            ToggleFrame.Parent           = self.Container
            Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(ToggleFrame)
        
            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size            = UDim2.new(0.65, 0, 1, 0)
            TitleLabel.Position        = UDim2.new(0, ES(10), 0, 0)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text            = Title
            TitleLabel.TextColor3      = T.TextPrimary
            TitleLabel.Font            = Enum.Font.GothamMedium
            TitleLabel.TextSize        = FS(12)
            TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
            TitleLabel.Parent          = ToggleFrame
        
            local ToggleBG = Instance.new("TextButton")
            ToggleBG.Size             = UDim2.new(0, ES(34), 0, ES(18))
            ToggleBG.AnchorPoint      = Vector2.new(1, 0.5)
            ToggleBG.Position         = UDim2.new(1, -ES(8), 0.5, 0)
            ToggleBG.BackgroundColor3 = Toggled and T.Accent or T.SurfaceDeep
            ToggleBG.Text             = ""
            ToggleBG.Parent           = ToggleFrame
            Instance.new("UICorner", ToggleBG).CornerRadius = UDim.new(1, 0)
            AddDepthStroke(ToggleBG)
        
            local dotOff = ES(3)
            local dotOn  = ES(34) - ES(15)
            local dotSz  = ES(12)
            local ToggleDot = Instance.new("Frame")
            ToggleDot.Size             = UDim2.new(0, dotSz, 0, dotSz)
            ToggleDot.Position         = Toggled and UDim2.new(0, dotOn, 0.5, -dotSz/2) or UDim2.new(0, dotOff, 0.5, -dotSz/2)
            ToggleDot.BackgroundColor3 = T.TextWhite
            ToggleDot.Parent           = ToggleBG
            Instance.new("UICorner", ToggleDot).CornerRadius = UDim.new(1, 0)
        
            local function ApplyVisual(state)
                local targetPos = state and UDim2.new(0, dotOn, 0.5, -dotSz/2) or UDim2.new(0, dotOff, 0.5, -dotSz/2)
                local targetCol = state and T.Accent or T.SurfaceDeep
                TweenService:Create(ToggleDot, TweenInfo.new(0.2), {Position = targetPos}):Play()
                TweenService:Create(ToggleBG,  TweenInfo.new(0.2), {BackgroundColor3 = targetCol}):Play()
            end
        
            ToggleBG.MouseButton1Click:Connect(function()
                if toggleDisabled then return end
                Toggled = not Toggled
                ApplyVisual(Toggled)
                Callback(Toggled)
            end)
        
            function Element:SetState(state)
                if state == Toggled then return end
                Toggled = state
                ApplyVisual(Toggled)
            end
        
            function Element:SetDisabled(state)
                toggleDisabled = state
                ToggleBG.Active = not state
                TweenService:Create(ToggleBG, TweenInfo.new(0.2), {
                    BackgroundTransparency = state and 0.5 or 0,
                    BackgroundColor3       = state and T.Surface or (Toggled and T.Accent or T.SurfaceDeep),
                }):Play()
                TweenService:Create(ToggleDot, TweenInfo.new(0.2), {
                    BackgroundTransparency = state and 0.5 or 0,
                }):Play()
                TitleLabel.TextColor3 = state and T.TextSecondary or T.TextPrimary
            end
        
            return AttachTooltip(TitleLabel, Element)
        end
        
        -- ── IMAGE ─────────────────────────────────────────────────────────
        function Tab:CreateImage(FileName, Height)
            local Element = {}
            local CardH   = ES(Height or 80)
        
            -- ── Use ImageLabel as the card itself so UICorner rounds the image
            --    content properly — ClipsDescendants only clips to a rectangle,
            --    so the old Frame+ClipFrame approach never worked.
            local ImageFrame = Instance.new("ImageLabel")
            ImageFrame.Size             = UDim2.new(1, 0, 0, CardH)
            ImageFrame.BackgroundColor3 = T.Surface
            ImageFrame.Image            = ""
            ImageFrame.ScaleType        = Enum.ScaleType.Stretch
            ImageFrame.ImageColor3      = Color3.new(1, 1, 1)
            ImageFrame.Parent           = self.Container
            Instance.new("UICorner", ImageFrame).CornerRadius = UDim.new(0, 6)
        
            -- ── STROKE overlay: transparent frame on top with high ZIndex.
            local StrokeFrame = Instance.new("Frame")
            StrokeFrame.Size                   = UDim2.new(1, 0, 1, 0)
            StrokeFrame.BackgroundTransparency = 1
            StrokeFrame.ZIndex                 = 10
            StrokeFrame.Parent                 = ImageFrame
            Instance.new("UICorner", StrokeFrame).CornerRadius = UDim.new(0, 6)
            local Stroke = Instance.new("UIStroke", StrokeFrame)
            Stroke.Color           = T.Stroke
            Stroke.Thickness       = 1
            Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        
            -- ── Loader
            local function LoadImage(fileName)
                if not fileName or fileName == "" then return end
                task.spawn(function()
                    local localPath = "Dynxe/Images/" .. fileName
                    local asset
        
                    if isfile and getcustomasset and isfile(localPath) then
                        asset = getcustomasset(localPath)
                    else
                        local url = string.format(
                            "https://raw.githubusercontent.com/%s/%s/%s/Images/%s",
                            User, Repo, Branch, fileName
                        )
                        local ok, content = pcall(function() return game:HttpGet(url) end)
                        if ok and content
                        and not content:find("404: Not Found")
                        and #content > 100 then
                            if isfolder and makefolder and writefile and getcustomasset then
                                if not isfolder("Dynxe")        then makefolder("Dynxe")        end
                                if not isfolder("Dynxe/Images") then makefolder("Dynxe/Images") end
                                writefile(localPath, content)
                                asset = getcustomasset(localPath)
                            end
                        else
                            warn("[CreateImage] Asset missing: " .. fileName)
                        end
                    end
        
                    if asset then ImageFrame.Image = asset end
                end)
            end
        
            LoadImage(FileName)
        
            -- ── Public API
            function Element:SetImage(fileName)   LoadImage(fileName)                          end
            function Element:SetHeight(pts)       ImageFrame.Size = UDim2.new(1, 0, 0, ES(pts)) end
            function Element:SetImageColor(color) ImageFrame.ImageColor3 = color               end
            function Element:SetTransparency(v)   ImageFrame.ImageTransparency = math.clamp(v, 0, 1) end
            function Element:SetVisible(state)    ImageFrame.Visible = state                   end
        
            return Element
        end
        
        -- ── INPUT ─────────────────────────────────────────────
        function Tab:CreateInput(Title, Placeholder, Callback)
            local Element   = {}
            local RowHeight = ES(28)
            local BoxWidth  = ES(70) -- Width for the input area
            local BoxHeight = ES(20)

            local InputFrame = Instance.new("Frame")
            InputFrame.Size             = UDim2.new(1, 0, 0, RowHeight)
            InputFrame.BackgroundColor3 = T.Surface
            InputFrame.Parent           = self.Container
            Instance.new("UICorner", InputFrame).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(InputFrame)

            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size            = UDim2.new(0.6, 0, 1, 0)
            TitleLabel.Position        = UDim2.new(0, ES(10), 0, 0)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text            = Title
            TitleLabel.TextColor3      = T.TextPrimary
            TitleLabel.Font            = Enum.Font.GothamMedium
            TitleLabel.TextSize        = FS(12)
            TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
            TitleLabel.Parent          = InputFrame

            local InputBox = Instance.new("TextBox")
            InputBox.Name              = "InputBox"
            InputBox.Size              = UDim2.new(0, BoxWidth, 0, BoxHeight)
            InputBox.AnchorPoint       = Vector2.new(1, 0.5)
            InputBox.Position          = UDim2.new(1, -ES(8), 0.5, 0)
            InputBox.BackgroundColor3  = T.SurfaceDeep
            InputBox.Text              = ""
            InputBox.PlaceholderText   = Placeholder
            InputBox.PlaceholderColor3 = T.TextSecondary
            InputBox.TextColor3        = T.TextWhite
            InputBox.Font              = Enum.Font.GothamMedium
            InputBox.TextSize          = FS(11)
            InputBox.ClipsDescendants  = true
            InputBox.ClearTextOnFocus  = false
            InputBox.Parent            = InputFrame
            Instance.new("UICorner", InputBox).CornerRadius = UDim.new(0, 4)
            AddDepthStroke(InputBox)

            -- Interaction Logic
            InputBox.FocusLost:Connect(function(enterPressed)
                Callback(InputBox.Text)
                TweenService:Create(InputBox, TweenInfo.new(0.2), {BackgroundColor3 = T.SurfaceDeep}):Play()
            end)

            InputBox.Focused:Connect(function()
                TweenService:Create(InputBox, TweenInfo.new(0.2), {BackgroundColor3 = T.Stroke}):Play()
            end)

            -- Public Methods
            function Element:SetText(val)
                InputBox.Text = tostring(val)
            end

            function Element:GetText()
                return InputBox.Text
            end

            return AttachTooltip(TitleLabel, Element)
        end
        
        -- ── SLIDER ────────────────────────────────────────────────────
        function Tab:CreateSlider(Title, Min, Max, Default, Callback, Decimals)
            Decimals = Decimals or 0  -- default = integers, pass e.g. 1 or 2 for decimals
        
            local Element        = {}
            local sliderDisabled = false
            local RowHeight      = ES(38)
        
            local function RoundValue(v)
                if Decimals == 0 then
                    return math.floor(v)
                end
                local factor = 10 ^ Decimals
                return math.floor(v * factor + 0.5) / factor
            end
        
            local SliderFrame = Instance.new("Frame")
            SliderFrame.Size             = UDim2.new(1, 0, 0, RowHeight)
            SliderFrame.BackgroundColor3 = T.Surface
            SliderFrame.Parent           = self.Container
            Instance.new("UICorner", SliderFrame).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(SliderFrame)
        
            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size            = UDim2.new(1, -ES(70), 0, ES(20))
            TitleLabel.Position        = UDim2.new(0, ES(10), 0, ES(4))
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text            = Title
            TitleLabel.TextColor3      = T.TextPrimary
            TitleLabel.Font            = Enum.Font.GothamMedium
            TitleLabel.TextSize        = FS(12)
            TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
            TitleLabel.Parent          = SliderFrame
        
            local ValueLabel = Instance.new("TextLabel")
            ValueLabel.Size            = UDim2.new(0, ES(55), 0, ES(20))
            ValueLabel.AnchorPoint     = Vector2.new(1, 0)
            ValueLabel.Position        = UDim2.new(1, -ES(8), 0, ES(4))
            ValueLabel.BackgroundTransparency = 1
            ValueLabel.Text            = tostring(RoundValue(Default))
            ValueLabel.TextColor3      = T.Accent
            ValueLabel.Font            = Enum.Font.GothamBold
            ValueLabel.TextSize        = FS(12)
            ValueLabel.TextXAlignment  = Enum.TextXAlignment.Right
            ValueLabel.Parent          = SliderFrame
        
            local trackY = ES(28)
            local SliderBG = Instance.new("Frame")
            SliderBG.Size             = UDim2.new(1, -ES(20), 0, ES(4))
            SliderBG.Position         = UDim2.new(0, ES(10), 0, trackY)
            SliderBG.BackgroundColor3 = T.SurfaceDeep
            SliderBG.Parent           = SliderFrame
            Instance.new("UICorner", SliderBG)
        
            local SliderFill = Instance.new("Frame")
            SliderFill.Size             = UDim2.new((Default - Min) / (Max - Min), 0, 1, 0)
            SliderFill.BackgroundColor3 = T.Accent
            SliderFill.BorderSizePixel  = 0
            SliderFill.Parent           = SliderBG
            Instance.new("UICorner", SliderFill)
        
            local SliderBtn = Instance.new("TextButton")
            SliderBtn.Size               = UDim2.new(1, 0, 1, 0)
            SliderBtn.BackgroundTransparency = 1
            SliderBtn.Text               = ""
            SliderBtn.ZIndex             = SliderFrame.ZIndex + 5
            SliderBtn.Parent             = SliderFrame
        
            local function UpdateSlider()
                local mousePos = UserInputService:GetMouseLocation().X
                local barPos   = SliderBG.AbsolutePosition.X
                local barWidth = SliderBG.AbsoluteSize.X
                local pct      = math.clamp((mousePos - barPos) / barWidth, 0, 1)
                local value    = RoundValue(Min + (Max - Min) * pct)
                SliderFill.Size = UDim2.new(pct, 0, 1, 0)
                ValueLabel.Text = tostring(value)
                Callback(value)
            end
        
            -- PUBLIC: set value programmatically without firing Callback
            function Element:SetValue(value)
                value = math.clamp(RoundValue(value), Min, Max)
                local pct = (value - Min) / (Max - Min)
                SliderFill.Size = UDim2.new(pct, 0, 1, 0)
                ValueLabel.Text = tostring(value)
            end
        
            -- PUBLIC: disable / enable
            function Element:SetDisabled(state)
                sliderDisabled = state
                TweenService:Create(SliderFill, TweenInfo.new(0.2), {
                    BackgroundColor3 = state and T.TextSecondary or T.Accent
                }):Play()
                TweenService:Create(SliderBG, TweenInfo.new(0.2), {
                    BackgroundTransparency = state and 0.5 or 0
                }):Play()
                ValueLabel.TextColor3 = state and T.TextSecondary or T.Accent
                TitleLabel.TextColor3 = state and T.TextSecondary or T.TextPrimary
                SliderBtn.Active      = not state
            end
        
            local sliding = false
            SliderBtn.InputBegan:Connect(function(input)
                if sliderDisabled then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    sliding = true
                    UpdateSlider()
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    sliding = false
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if sliding and not sliderDisabled and input.UserInputType == Enum.UserInputType.MouseMovement then
                    UpdateSlider()
                end
            end)
        
            return AttachTooltip(TitleLabel, Element)
        end

        -- ── KEYBIND ───────────────────────────────────────────
        function Tab:CreateKeybind(Title, Default, Callback)
            local Element   = {}
            local KeyName   = (typeof(Default) == "EnumItem") and Default.Name or Default.UserInputType.Name
            local RowHeight = ES(28)

            local KeybindFrame = Instance.new("Frame")
            KeybindFrame.Size             = UDim2.new(1, 0, 0, RowHeight)
            KeybindFrame.BackgroundColor3 = T.Surface
            KeybindFrame.Parent           = self.Container
            Instance.new("UICorner", KeybindFrame).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(KeybindFrame)

            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size            = UDim2.new(0.65, 0, 1, 0)
            TitleLabel.Position        = UDim2.new(0, ES(10), 0, 0)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text            = Title
            TitleLabel.TextColor3      = T.TextPrimary
            TitleLabel.Font            = Enum.Font.GothamMedium
            TitleLabel.TextSize        = FS(12)
            TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
            TitleLabel.Parent          = KeybindFrame

            local BindBtn = Instance.new("TextButton")
            BindBtn.Size             = UDim2.new(0, ES(70), 0, ES(20))
            BindBtn.AnchorPoint      = Vector2.new(1, 0.5)
            BindBtn.Position         = UDim2.new(1, -ES(8), 0.5, 0)
            BindBtn.BackgroundColor3 = T.SurfaceDeep
            BindBtn.Text             = KeyName
            BindBtn.TextColor3       = T.TextWhite
            BindBtn.Font             = Enum.Font.GothamBold
            BindBtn.TextSize         = FS(11)
            BindBtn.Parent           = KeybindFrame
            Instance.new("UICorner", BindBtn).CornerRadius = UDim.new(0, 4)
            AddDepthStroke(BindBtn)

            BindBtn.MouseButton1Click:Connect(function()
                BindBtn.Text = "..."
                local conn
                conn = UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        KeyName = input.KeyCode.Name; BindBtn.Text = KeyName; conn:Disconnect()
                    elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                        KeyName = input.UserInputType.Name; BindBtn.Text = KeyName; conn:Disconnect()
                    end
                end)
            end)
            UserInputService.InputBegan:Connect(function(input, processed)
                if not processed then
                    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == KeyName then
                        Callback()
                    elseif input.UserInputType.Name == KeyName then
                        Callback()
                    end
                end
            end)

            return AttachTooltip(TitleLabel, Element)
        end

        -- ── INFO BOX (v2) ─────────────────────────────────────────────
        -- Looks like CreateAction (flat Surface card, rounded corners, depth stroke).
        -- No button. Accepts unlimited text entries via :AddText(), each fully
        -- configurable. Card height is automatic — grows with content.
        -- Also exposes :AddDivider() and :AddSpacer() for layout control.
        -- ──────────────────────────────────────────────────────────────
        function Tab:CreateInfoBox()
            local InfoBox    = {}
            local layoutOrder = 0
        
            -- ── Outer card (matches Action button style exactly) ──────
            local Card = Instance.new("Frame")
            Card.Name             = "InfoBox"
            Card.Size             = UDim2.new(1, 0, 0, 0)
            Card.AutomaticSize    = Enum.AutomaticSize.Y
            Card.BackgroundColor3 = T.Surface
            Card.BorderSizePixel  = 0
            Card.ClipsDescendants = false
            Card.Parent           = self.Container
            Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(Card)
        
            -- ── Inner layout container with shared padding ────────────
            local Inner = Instance.new("Frame")
            Inner.Name                = "Inner"
            Inner.Size                = UDim2.new(1, 0, 0, 0)
            Inner.AutomaticSize       = Enum.AutomaticSize.Y
            Inner.BackgroundTransparency = 1
            Inner.Parent              = Card
        
            local InnerPad = Instance.new("UIPadding", Inner)
            InnerPad.PaddingLeft   = UDim.new(0, ES(10))
            InnerPad.PaddingRight  = UDim.new(0, ES(10))
            InnerPad.PaddingTop    = UDim.new(0, ES(6))
            InnerPad.PaddingBottom = UDim.new(0, ES(6))
        
            local InnerLayout = Instance.new("UIListLayout", Inner)
            InnerLayout.SortOrder     = Enum.SortOrder.LayoutOrder
            InnerLayout.FillDirection = Enum.FillDirection.Vertical
            InnerLayout.Padding       = UDim.new(0, ES(3))
        
            -- ─────────────────────────────────────────────────────────
            -- :AddText(content, opts)
            --
            -- Appends a TextLabel to the card. Returns a Handle with
            -- setter methods so you can update any property at runtime.
            --
            -- opts fields (all optional):
            --   Font        Enum.Font              Gotham
            --   Size        number (pt)            12
            --   Color       Color3                 T.TextPrimary
            --   XAlignment  Enum.TextXAlignment    Left
            --   YAlignment  Enum.TextYAlignment    Center
            --   Rotation    number (degrees)       0
            --   Wrap        boolean                true
            --   RichText    boolean                false
            --   Bold        boolean                false   (shortcut; overrides Font)
            --   Italic      boolean                false   (wraps text in <i> via RichText)
            --   Opacity     number 0–1             1       (TextTransparency)
            --   PaddingTop / PaddingBottom / PaddingLeft / PaddingRight
            --               number (pts)           —       per-element extra spacing
            -- ─────────────────────────────────────────────────────────
            function InfoBox:AddText(content, opts)
                opts = opts or {}
                layoutOrder = layoutOrder + 1
        
                -- Resolve font: Bold shortcut overrides Font field
                local resolvedFont = opts.Font or Enum.Font.Gotham
                if opts.Bold then resolvedFont = Enum.Font.GothamBold end
        
                -- Resolve content: Italic shortcut wraps in RichText tag
                local resolvedContent = tostring(content or "")
                local useRichText     = opts.RichText or false
                if opts.Italic then
                    resolvedContent = "<i>" .. resolvedContent .. "</i>"
                    useRichText     = true
                end
        
                local Label = Instance.new("TextLabel")
                Label.Name                = "InfoText_" .. layoutOrder
                Label.LayoutOrder         = layoutOrder
                Label.Size                = UDim2.new(1, 0, 0, 0)
                Label.AutomaticSize       = Enum.AutomaticSize.Y
                Label.BackgroundTransparency = 1
                Label.Text                = resolvedContent
                Label.Font                = resolvedFont
                Label.TextSize            = FS(opts.Size or 12)
                Label.TextColor3          = opts.Color or T.TextPrimary
                Label.TextXAlignment      = opts.XAlignment or Enum.TextXAlignment.Left
                Label.TextYAlignment      = opts.YAlignment or Enum.TextYAlignment.Center
                Label.TextWrapped         = (opts.Wrap ~= false)
                Label.RichText            = useRichText
                Label.Rotation            = opts.Rotation or 0
                Label.TextTransparency    = opts.Opacity ~= nil and (1 - opts.Opacity) or 0
                Label.Parent              = Inner
        
                -- Per-element extra padding (applied via UIPadding on the label itself)
                if opts.PaddingTop or opts.PaddingBottom or opts.PaddingLeft or opts.PaddingRight then
                    local Pad = Instance.new("UIPadding", Label)
                    Pad.PaddingTop    = UDim.new(0, ES(opts.PaddingTop    or 0))
                    Pad.PaddingBottom = UDim.new(0, ES(opts.PaddingBottom or 0))
                    Pad.PaddingLeft   = UDim.new(0, ES(opts.PaddingLeft   or 0))
                    Pad.PaddingRight  = UDim.new(0, ES(opts.PaddingRight  or 0))
                end
        
                -- ── Handle — every property settable at runtime ───────
                local Handle = {}
        
                -- Text content
                function Handle:Set(text)
                    local str = tostring(text)
                    if opts.Italic then str = "<i>" .. str .. "</i>" end
                    Label.Text = str
                end
        
                -- Colour
                function Handle:SetColor(color)
                    Label.TextColor3 = color
                end
        
                -- Font size (runs through FS() scale helper)
                function Handle:SetSize(pts)
                    Label.TextSize = FS(pts)
                end
        
                -- Font family
                function Handle:SetFont(font)
                    Label.Font = font
                end
        
                -- Rotation in degrees
                function Handle:SetRotation(degrees)
                    Label.Rotation = degrees
                end
        
                -- Opacity: 1 = fully visible, 0 = invisible
                function Handle:SetOpacity(value)
                    Label.TextTransparency = 1 - math.clamp(value, 0, 1)
                end
        
                -- Horizontal text alignment
                function Handle:SetXAlignment(alignment)
                    Label.TextXAlignment = alignment
                end
        
                -- Vertical text alignment
                function Handle:SetYAlignment(alignment)
                    Label.TextYAlignment = alignment
                end
        
                -- Text wrapping
                function Handle:SetWrap(state)
                    Label.TextWrapped = state
                end
        
                -- RichText on/off
                function Handle:SetRichText(state)
                    Label.RichText = state
                end
        
                -- Tween any numeric or Color3 property smoothly
                function Handle:Tween(props, duration, style, direction)
                    TweenService:Create(
                        Label,
                        TweenInfo.new(
                            duration  or 0.25,
                            style     or Enum.EasingStyle.Quad,
                            direction or Enum.EasingDirection.Out
                        ),
                        props
                    ):Play()
                end
        
                -- Visibility
                function Handle:SetVisible(state)
                    Label.Visible = state
                end
        
                -- Remove this text element from the card entirely
                function Handle:Destroy()
                    Label:Destroy()
                end
        
                return Handle
            end
        
            -- ─────────────────────────────────────────────────────────
            -- :AddDivider(color, thickness)
            --
            -- Inserts a horizontal rule between text entries.
            --   color      Color3    T.Stroke
            --   thickness  number    1  (pixels)
            -- ─────────────────────────────────────────────────────────
            function InfoBox:AddDivider(color, thickness)
                layoutOrder = layoutOrder + 1
                local Line = Instance.new("Frame")
                Line.LayoutOrder        = layoutOrder
                Line.Size               = UDim2.new(1, 0, 0, math.max(1, thickness or 1))
                Line.BackgroundColor3   = color or T.Stroke
                Line.BorderSizePixel    = 0
                Line.Parent             = Inner
            end
        
            -- ─────────────────────────────────────────────────────────
            -- :AddSpacer(height)
            --
            -- Inserts invisible vertical space (in scaled points).
            --   height  number  4
            -- ─────────────────────────────────────────────────────────
            function InfoBox:AddSpacer(height)
                layoutOrder = layoutOrder + 1
                local Gap = Instance.new("Frame")
                Gap.LayoutOrder           = layoutOrder
                Gap.Size                  = UDim2.new(1, 0, 0, ES(height or 4))
                Gap.BackgroundTransparency = 1
                Gap.Parent                = Inner
            end
        
            -- ─────────────────────────────────────────────────────────
            -- :SetPadding(top, bottom, left, right)
            --
            -- Override the card's inner edge padding (scaled points).
            -- ─────────────────────────────────────────────────────────
            function InfoBox:SetPadding(top, bottom, left, right)
                InnerPad.PaddingTop    = UDim.new(0, ES(top    or 6))
                InnerPad.PaddingBottom = UDim.new(0, ES(bottom or 6))
                InnerPad.PaddingLeft   = UDim.new(0, ES(left   or 10))
                InnerPad.PaddingRight  = UDim.new(0, ES(right  or 10))
            end
        
            -- ─────────────────────────────────────────────────────────
            -- :SetSpacing(pts)
            --
            -- Override the gap between stacked text entries.
            --   pts  number  3
            -- ─────────────────────────────────────────────────────────
            function InfoBox:SetSpacing(pts)
                InnerLayout.Padding = UDim.new(0, ES(pts))
            end
        
            -- ─────────────────────────────────────────────────────────
            -- :SetBackground(color)
            --
            -- Change the card's background colour at runtime.
            -- ─────────────────────────────────────────────────────────
            function InfoBox:SetBackground(color)
                Card.BackgroundColor3 = color
            end
        
            -- ─────────────────────────────────────────────────────────
            -- :SetStroke(color, thickness)
            --
            -- Change the card's border colour and thickness.
            -- ─────────────────────────────────────────────────────────
            function InfoBox:SetStroke(color, thickness)
                local stroke = Card:FindFirstChildOfClass("UIStroke")
                if stroke then
                    stroke.Color     = color     or T.Stroke
                    stroke.Thickness = thickness or 1
                end
            end
        
            return InfoBox
        end
                
        -- ── IMAGE SELECTOR ────────────────────────────────────
        function Tab:CreateImageSelector(Title, Config2, Callback)
            local Element = {Selected = {}}
            Config2 = Config2 or {}
            local Multi       = Config2.MultiSelect or false
            local SlotSize    = Config2.SlotSize or UDim2.new(0, ES(70), 0, ES(70))
            -- VisibleRows controls how tall the visible window is before
            -- scrolling kicks in. Slots still wrap automatically based on
            -- available width — no manual Rows needed.
            local VisibleRows = Config2.VisibleRows or 2

            local SCROLLBAR_W   = 4              -- 2× the old 2 px
            local FADE_H        = ES(16)          -- height of top/bottom fade bands
            local TopPadding    = ES(35)
            local BottomPadding = ES(10)
            local CellPaddingX  = ES(8)
            local CellPaddingY  = ES(8)
            local ScrollHeight  = (SlotSize.Y.Offset * VisibleRows)
                                + (CellPaddingY   * (VisibleRows - 1))
                                + 6
            local TotalHeight   = TopPadding + ScrollHeight + BottomPadding

            local SlotRegistry = {}

            -- ── Outer card ────────────────────────────────────────
            local SelectorFrame = Instance.new("Frame")
            SelectorFrame.Name             = Title .. "_ImageSelector"
            SelectorFrame.Size             = UDim2.new(1, 0, 0, TotalHeight)
            SelectorFrame.BackgroundColor3 = T.Surface
            SelectorFrame.Parent           = self.Container
            Instance.new("UICorner", SelectorFrame).CornerRadius = UDim.new(0, 6)

            local FrameStroke = Instance.new("UIStroke", SelectorFrame)
            FrameStroke.Color     = T.Stroke
            FrameStroke.Thickness = 1

            -- ── Header ────────────────────────────────────────────
            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size                   = UDim2.new(0.5, 0, 0, ES(20))
            TitleLabel.Position               = UDim2.new(0, ES(10), 0, ES(8))
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text                   = Title
            TitleLabel.TextColor3             = T.TextPrimary
            TitleLabel.Font                   = Enum.Font.GothamMedium
            TitleLabel.TextSize               = FS(13)
            TitleLabel.TextXAlignment         = Enum.TextXAlignment.Left
            TitleLabel.Parent                 = SelectorFrame

            local SearchBox = Instance.new("TextBox")
            SearchBox.Name              = "SearchBox"
            SearchBox.Size              = UDim2.new(0, ES(150), 0, ES(20))
            SearchBox.AnchorPoint       = Vector2.new(1, 0)
            SearchBox.Position          = UDim2.new(1, -ES(10), 0, ES(8))
            SearchBox.BackgroundColor3  = T.SurfaceDeep
            SearchBox.PlaceholderText   = "Search…"
            SearchBox.PlaceholderColor3 = T.TextSecondary
            SearchBox.Text              = ""
            SearchBox.TextColor3        = T.TextPrimary
            SearchBox.Font              = Enum.Font.Gotham
            SearchBox.TextSize          = FS(11)
            SearchBox.ClearTextOnFocus  = false
            SearchBox.ClipsDescendants  = true
            SearchBox.Parent            = SelectorFrame
            Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 4)

            local SearchStroke = Instance.new("UIStroke", SearchBox)
            SearchStroke.Color     = T.Stroke
            SearchStroke.Thickness = 1

            local SearchPad = Instance.new("UIPadding", SearchBox)
            SearchPad.PaddingLeft  = UDim.new(0, ES(6))
            SearchPad.PaddingRight = UDim.new(0, ES(6))

            SearchBox.Focused:Connect(function()
                TweenService:Create(SearchStroke, TweenInfo.new(0.2), {Color = T.Accent}):Play()
            end)
            SearchBox.FocusLost:Connect(function()
                TweenService:Create(SearchStroke, TweenInfo.new(0.2), {Color = T.Stroke}):Play()
            end)

            -- ── Scroll area — vertical, scrollbar on right ─────────
            local Scroll = Instance.new("ScrollingFrame")
            Scroll.Size                      = UDim2.new(1, -ES(20), 0, ScrollHeight)
            Scroll.Position                  = UDim2.new(0, ES(10), 0, TopPadding)
            Scroll.BackgroundTransparency    = 1
            Scroll.BorderSizePixel           = 0
            Scroll.CanvasSize                = UDim2.new(0, 0, 0, 0)
            Scroll.ScrollBarThickness        = SCROLLBAR_W
            Scroll.ScrollBarImageColor3      = T.Accent
            Scroll.ScrollBarImageTransparency = 0
            Scroll.ScrollingDirection        = Enum.ScrollingDirection.Y   -- vertical
            Scroll.ClipsDescendants          = true
            Scroll.Parent                    = SelectorFrame

            -- Slots fill left-to-right and wrap to the next row automatically
            local Layout = Instance.new("UIGridLayout", Scroll)
            Layout.CellSize             = SlotSize
            Layout.CellPadding          = UDim2.new(0, CellPaddingX, 0, CellPaddingY)
            Layout.SortOrder            = Enum.SortOrder.LayoutOrder
            Layout.FillDirection        = Enum.FillDirection.Horizontal
            Layout.HorizontalAlignment  = Enum.HorizontalAlignment.Left
            Layout.VerticalAlignment    = Enum.VerticalAlignment.Top

            -- Right padding keeps slots clear of the scrollbar track
            local Padding = Instance.new("UIPadding", Scroll)
            Padding.PaddingLeft   = UDim.new(0, 2)
            Padding.PaddingTop    = UDim.new(0, ES(3))
            Padding.PaddingBottom = UDim.new(0, ES(3))
            Padding.PaddingRight  = UDim.new(0, SCROLLBAR_W + 2)

            -- Canvas grows as rows are added
            Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                Scroll.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + ES(6))
            end)

            -- ── Top / bottom edge fades ────────────────────────────
            -- Parented to SelectorFrame so UIGridLayout ignores them.
            -- Width matches the Scroll area minus the scrollbar strip.
            -- Rotation 90  = gradient runs top→bottom (keypoint 0 at top).
            -- Rotation 270 = gradient runs bottom→top (keypoint 0 at bottom).
            local FADE_W_OFFSET = -ES(20) - SCROLLBAR_W - 2

            local function MakeVerticalFade(isBottom)
                local Fade = Instance.new("Frame")
                Fade.Size                   = UDim2.new(1, FADE_W_OFFSET, 0, FADE_H)
                Fade.AnchorPoint            = Vector2.new(0, isBottom and 1 or 0)
                Fade.Position               = UDim2.new(
                    0, ES(10),
                    0, isBottom and (TopPadding + ScrollHeight) or TopPadding
                )
                Fade.BackgroundColor3       = T.Surface
                Fade.BackgroundTransparency = 0
                Fade.BorderSizePixel        = 0
                Fade.ZIndex                 = 5
                Fade.Parent                 = SelectorFrame
                local Grad = Instance.new("UIGradient", Fade)
                Grad.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),   -- opaque at gradient start
                    NumberSequenceKeypoint.new(1, 1),   -- transparent at gradient end
                })
                -- Top fade:    opaque at top, transparent at bottom → rotation 90
                -- Bottom fade: opaque at bottom, transparent at top → rotation 270
                Grad.Rotation = isBottom and 270 or 90
            end

            MakeVerticalFade(false)   -- top
            MakeVerticalFade(true)    -- bottom

            -- ── Search filter ─────────────────────────────────────
            local function ApplySearch(query)
                query = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
                for _, entry in ipairs(SlotRegistry) do
                    entry.slot.Visible = query == ""
                        or entry.title:lower():find(query, 1, true) ~= nil
                end
                task.defer(function()
                    Scroll.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + ES(6))
                end)
            end

            SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
                ApplySearch(SearchBox.Text)
            end)

            -- ── AddSlot ───────────────────────────────────────────
            function Element:AddSlot(ID, SlotTitle, SlotSubText)
                local Slot = Instance.new("TextButton")
                Slot.BackgroundColor3 = T.SurfaceDeep
                Slot.Text             = ""
                Slot.ZIndex           = 2
                Slot.Parent           = Scroll
                Instance.new("UICorner", Slot).CornerRadius = UDim.new(0, 6)

                local Stroke = Instance.new("UIStroke", Slot)
                Stroke.Color           = T.Stroke
                Stroke.Thickness       = 1.2
                Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

                local Image = Instance.new("ImageLabel")
                Image.Size                   = UDim2.new(0.75, 0, 0.75, 0)
                Image.Position               = UDim2.new(0.5, 0, 0.5, 0)
                Image.AnchorPoint            = Vector2.new(0.5, 0.5)
                Image.BackgroundTransparency = 1
                Image.Image                  = ID
                Image.ZIndex                 = 2
                Image.Parent                 = Slot

                if SlotTitle or SlotSubText then
                    Image.Position = UDim2.new(0.5, 0, 0.35, 0)
                    Image.Size     = UDim2.new(0.55, 0, 0.55, 0)
                end

                local TitleFades = {}

                if SlotTitle then
                    local TitleClip = Instance.new("Frame")
                    TitleClip.Size                   = UDim2.new(1, -ES(6), 0, FS(13))
                    TitleClip.Position               = UDim2.new(0, ES(3), 0.65, 0)
                    TitleClip.BackgroundTransparency = 1
                    TitleClip.ClipsDescendants       = true
                    TitleClip.ZIndex                 = 2
                    TitleClip.Parent                 = Slot

                    local Measure = Instance.new("TextLabel")
                    Measure.Size                   = UDim2.new(0, 500, 1, 0)
                    Measure.Position               = UDim2.new(0, -1000, 0, 0)
                    Measure.BackgroundTransparency = 1
                    Measure.Text                   = SlotTitle
                    Measure.Font                   = Enum.Font.GothamMedium
                    Measure.TextSize               = FS(10)
                    Measure.TextWrapped            = false
                    Measure.Parent                 = TitleClip

                    task.defer(function()
                        if not Slot.Parent then return end

                        local clipW = TitleClip.AbsoluteSize.X
                        local textW = Measure.TextBounds.X
                        Measure:Destroy()

                        if textW <= clipW then
                            local Txt = Instance.new("TextLabel")
                            Txt.Size                   = UDim2.new(1, 0, 1, 0)
                            Txt.BackgroundTransparency = 1
                            Txt.Text                   = SlotTitle
                            Txt.TextColor3             = T.TextPrimary
                            Txt.Font                   = Enum.Font.GothamMedium
                            Txt.TextSize               = FS(10)
                            Txt.ZIndex                 = 2
                            Txt.Parent                 = TitleClip
                        else
                            local GAP    = ES(18)
                            local totalW = textW + GAP

                            local Scroller = Instance.new("Frame")
                            Scroller.Size                   = UDim2.new(0, totalW * 2, 1, 0)
                            Scroller.Position               = UDim2.new(0, 0, 0, 0)
                            Scroller.BackgroundTransparency = 1
                            Scroller.ZIndex                 = 2
                            Scroller.Parent                 = TitleClip

                            for i = 0, 1 do
                                local Lbl = Instance.new("TextLabel")
                                Lbl.Size                   = UDim2.new(0, textW, 1, 0)
                                Lbl.Position               = UDim2.new(0, i * totalW, 0, 0)
                                Lbl.BackgroundTransparency = 1
                                Lbl.Text                   = SlotTitle
                                Lbl.TextColor3             = T.TextPrimary
                                Lbl.Font                   = Enum.Font.GothamMedium
                                Lbl.TextSize               = FS(10)
                                Lbl.TextXAlignment         = Enum.TextXAlignment.Left
                                Lbl.ZIndex                 = 2
                                Lbl.Parent                 = Scroller
                            end

                            local TITLE_FADE_W = ES(10)
                            local function MakeTitleFade(anchorX, posX, rotated)
                                local F = Instance.new("Frame")
                                F.Size             = UDim2.new(0, TITLE_FADE_W, 1, 0)
                                F.AnchorPoint      = Vector2.new(anchorX, 0)
                                F.Position         = UDim2.new(posX, 0, 0, 0)
                                F.BackgroundColor3 = T.SurfaceDeep
                                F.BorderSizePixel  = 0
                                F.ZIndex           = 4
                                F.Parent           = TitleClip
                                local G = Instance.new("UIGradient", F)
                                G.Transparency = NumberSequence.new({
                                    NumberSequenceKeypoint.new(0, 0),
                                    NumberSequenceKeypoint.new(1, 1),
                                })
                                if rotated then G.Rotation = 180 end
                                table.insert(TitleFades, F)
                            end
                            MakeTitleFade(0, 0, false)
                            MakeTitleFade(1, 1, true)

                            local SPEED          = 28
                            local scrollDuration = totalW / SPEED

                            task.spawn(function()
                                task.wait(1.2)
                                while Slot.Parent do
                                    local tween = TweenService:Create(
                                        Scroller,
                                        TweenInfo.new(scrollDuration, Enum.EasingStyle.Linear),
                                        { Position = UDim2.new(0, -totalW, 0, 0) }
                                    )
                                    tween:Play()
                                    tween.Completed:Wait()
                                    if not Slot.Parent then break end
                                    Scroller.Position = UDim2.new(0, 0, 0, 0)
                                end
                            end)
                        end
                    end)
                end

                if SlotSubText then
                    local SubTxt = Instance.new("TextLabel")
                    SubTxt.Size                   = UDim2.new(1, 0, 0, FS(12))
                    SubTxt.Position               = UDim2.new(0, 0, 0.82, 0)
                    SubTxt.BackgroundTransparency = 1
                    SubTxt.Text                   = SlotSubText
                    SubTxt.TextColor3             = T.Success
                    SubTxt.Font                   = Enum.Font.GothamBold
                    SubTxt.TextSize               = FS(9)
                    SubTxt.ZIndex                 = 2
                    SubTxt.Parent                 = Slot
                end

                table.insert(SlotRegistry, {
                    slot       = Slot,
                    title      = SlotTitle or "",
                    titleFades = TitleFades,
                })

                Slot.MouseButton1Click:Connect(function()
                    local isSelected = (Slot.BackgroundColor3 == T.Accent)

                    if not Multi then
                        for _, entry in ipairs(SlotRegistry) do
                            if entry.slot ~= Slot then
                                TweenService:Create(entry.slot, TweenInfo.new(0.2), {BackgroundColor3 = T.SurfaceDeep}):Play()
                                local s = entry.slot:FindFirstChildOfClass("UIStroke")
                                if s then s.Color = T.Stroke end
                                for _, fade in ipairs(entry.titleFades) do
                                    TweenService:Create(fade, TweenInfo.new(0.2), {BackgroundColor3 = T.SurfaceDeep}):Play()
                                end
                            end
                        end
                        Element.Selected = {SlotTitle or ID}
                    else
                        if isSelected then
                            for i, v in ipairs(Element.Selected) do
                                if v == (SlotTitle or ID) then
                                    table.remove(Element.Selected, i)
                                    break
                                end
                            end
                        else
                            table.insert(Element.Selected, SlotTitle or ID)
                        end
                    end

                    local targetColor = isSelected and T.SurfaceDeep or T.Accent
                    local strokeColor = isSelected and T.Stroke      or T.TextWhite

                    TweenService:Create(Slot, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
                    Stroke.Color = strokeColor

                    for _, fade in ipairs(TitleFades) do
                        TweenService:Create(fade, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
                    end

                    Callback(Multi and Element.Selected or Element.Selected[1])
                end)

                ApplySearch(SearchBox.Text)

                return Slot
            end

            return Element
        end

        -- ── DROPDOWN ──────────────────────────────────────────────────────
        -- Supports two modes detected automatically from the Options table:
        --
        -- TEXT MODE   — Options is a table of strings (existing behaviour)
        -- COLOR MODE  — Options is a table of Color3 values, or tables of
        --               the form { Name = "Label", Color = Color3 }
        --               Renders as full-width coloured rows, same layout as
        --               text mode but filled with the colour instead of text.
        --
        -- Public methods:
        --   Element:SetDisabled(state)        enable / disable the whole dropdown
        --   Element:SetOptions(newOptions)    replace the option list at runtime
        --   Element:SetSelected(val)          programmatically pick an option
        --   Element:AddTooltip(text)          attach a hover tooltip
        -- ──────────────────────────────────────────────────────────────────
        function Tab:CreateDropdown(Title, Options, Default, Callback)
            local Element      = {}
            local dropDisabled = false
            local RowHeight    = ES(28)
            local OptHeight    = ES(22)

            local function IsColorMode(opts)
                if not opts or #opts == 0 then return false end
                local first = opts[1]
                return typeof(first) == "Color3"
                    or (type(first) == "table" and typeof(first.Color) == "Color3")
            end

            local colorMode = IsColorMode(Options)

            local function Normalise(opt)
                if not colorMode then return opt end
                if typeof(opt) == "Color3" then return { Name = "", Color = opt } end
                return opt
            end

            local Selected = Default and Normalise(Default) or (Options[1] and Normalise(Options[1]))

            -- ── outer card ────────────────────────────────────────────
            local DropdownFrame = Instance.new("Frame")
            DropdownFrame.Size             = UDim2.new(1, 0, 0, RowHeight)
            DropdownFrame.BackgroundColor3 = T.Surface
            DropdownFrame.ClipsDescendants = true
            DropdownFrame.Parent           = self.Container
            Instance.new("UICorner", DropdownFrame).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(DropdownFrame)

            -- ── header ────────────────────────────────────────────────
            local Header = Instance.new("TextButton")
            Header.Size                   = UDim2.new(1, 0, 0, RowHeight)
            Header.BackgroundTransparency = 1
            Header.Text                   = ""
            Header.Parent                 = DropdownFrame

            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size            = UDim2.new(0.6, 0, 1, 0)
            TitleLabel.Position        = UDim2.new(0, ES(10), 0, 0)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text            = Title
            TitleLabel.TextColor3      = T.TextPrimary
            TitleLabel.Font            = Enum.Font.GothamMedium
            TitleLabel.TextSize        = FS(12)
            TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
            TitleLabel.Parent          = Header

            local SelectedLabel  = nil
            local SelectedSwatch = nil
            local SelectedName   = nil

            if colorMode then
                SelectedSwatch = Instance.new("Frame")
                SelectedSwatch.Size             = UDim2.new(0, ES(14), 0, ES(14))
                SelectedSwatch.AnchorPoint      = Vector2.new(1, 0.5)
                SelectedSwatch.Position         = UDim2.new(1, -ES(10), 0.5, 0)
                SelectedSwatch.BorderSizePixel  = 0
                SelectedSwatch.BackgroundColor3 = (Selected and Selected.Color) or Color3.new(1,1,1)
                SelectedSwatch.Parent           = Header
                Instance.new("UICorner", SelectedSwatch).CornerRadius = UDim.new(0, 3)
                local SwStroke = Instance.new("UIStroke", SelectedSwatch)
                SwStroke.Color = T.Stroke; SwStroke.Thickness = 1

                SelectedName = Instance.new("TextLabel")
                SelectedName.Size            = UDim2.new(0.35, 0, 1, 0)
                SelectedName.AnchorPoint     = Vector2.new(1, 0)
                SelectedName.Position        = UDim2.new(1, -ES(30), 0, 0)
                SelectedName.BackgroundTransparency = 1
                SelectedName.Text            = (Selected and Selected.Name) or ""
                SelectedName.TextColor3      = T.Accent
                SelectedName.Font            = Enum.Font.GothamBold
                SelectedName.TextSize        = FS(11)
                SelectedName.TextXAlignment  = Enum.TextXAlignment.Right
                SelectedName.TextTruncate    = Enum.TextTruncate.AtEnd
                SelectedName.Parent          = Header
            else
                SelectedLabel = Instance.new("TextLabel")
                SelectedLabel.Size            = UDim2.new(0.4, -25, 1, 0)
                SelectedLabel.Position        = UDim2.new(1, -10, 0, 0)
                SelectedLabel.AnchorPoint     = Vector2.new(1, 0)
                SelectedLabel.BackgroundTransparency = 1
                SelectedLabel.Text            = (type(Selected) == "string" and Selected) or "Select..."
                SelectedLabel.TextColor3      = T.Accent
                SelectedLabel.Font            = Enum.Font.GothamBold
                SelectedLabel.TextSize        = FS(11)
                SelectedLabel.TextXAlignment  = Enum.TextXAlignment.Right
                SelectedLabel.Parent          = Header
            end

            -- ── option container — always a vertical list ──────────────
            local OptionHolder = Instance.new("Frame")
            OptionHolder.Size             = UDim2.new(1, -ES(10), 0, 0)
            OptionHolder.Position         = UDim2.new(0, ES(5), 0, RowHeight + ES(4))
            OptionHolder.BackgroundTransparency = 1
            OptionHolder.Parent           = DropdownFrame

            local Layout = Instance.new("UIListLayout", OptionHolder)
            Layout.Padding   = UDim.new(0, ES(3))
            Layout.SortOrder = Enum.SortOrder.LayoutOrder

            local Dropdown = { Open = false }

            local function UpdateHeader(sel)
                Selected = sel
                if colorMode then
                    if SelectedSwatch then SelectedSwatch.BackgroundColor3 = sel and sel.Color or Color3.new(1,1,1) end
                    if SelectedName   then SelectedName.Text = (sel and sel.Name) or "" end
                else
                    if SelectedLabel  then SelectedLabel.Text = (type(sel) == "string" and sel) or "Select..." end
                end
            end

            local function GetOpenHeight()
                return RowHeight + ES(4) + Layout.AbsoluteContentSize.Y + ES(6)
            end

            local function Refresh()
                for _, child in pairs(OptionHolder:GetChildren()) do
                    if child:IsA("TextButton") or child:IsA("Frame") then child:Destroy() end
                end
                colorMode = IsColorMode(Options)

                for i, rawOpt in ipairs(Options) do
                    local opt = Normalise(rawOpt)

                    if colorMode then
                        -- ── FULL-WIDTH COLOR ROW ──────────────────────
                        local OptBtn = Instance.new("TextButton")
                        OptBtn.LayoutOrder      = i
                        OptBtn.Size             = UDim2.new(1, 0, 0, OptHeight)
                        OptBtn.BackgroundColor3 = opt.Color
                        OptBtn.Text             = ""
                        OptBtn.BorderSizePixel  = 0
                        OptBtn.Parent           = OptionHolder
                        Instance.new("UICorner", OptBtn).CornerRadius = UDim.new(0, 4)

                        local RowStroke = Instance.new("UIStroke", OptBtn)
                        RowStroke.Thickness = 1.5
                        local isSel = Selected and typeof(Selected) == "table" and Selected.Color == opt.Color
                        RowStroke.Color        = isSel and T.TextWhite or Color3.fromRGB(0,0,0)
                        RowStroke.Transparency = isSel and 0 or 0.85

                        if opt.Name and opt.Name ~= "" then
                            local NameLbl = Instance.new("TextLabel")
                            NameLbl.Size                  = UDim2.new(1, -ES(10), 1, 0)
                            NameLbl.Position              = UDim2.new(0, ES(8), 0, 0)
                            NameLbl.BackgroundTransparency = 1
                            NameLbl.Text                  = opt.Name
                            NameLbl.Font                  = Enum.Font.GothamBold
                            NameLbl.TextSize              = FS(11)
                            NameLbl.TextColor3            = Color3.new(1, 1, 1)
                            NameLbl.TextTransparency      = 0.2
                            NameLbl.TextXAlignment        = Enum.TextXAlignment.Left
                            NameLbl.TextStrokeColor3      = Color3.new(0, 0, 0)
                            NameLbl.TextStrokeTransparency = 0.5
                            NameLbl.Parent                = OptBtn
                        end

                        OptBtn.MouseButton1Click:Connect(function()
                            if dropDisabled then return end
                            for _, child in pairs(OptionHolder:GetChildren()) do
                                local s = child:FindFirstChildOfClass("UIStroke")
                                if s then s.Color = Color3.fromRGB(0,0,0); s.Transparency = 0.85 end
                            end
                            RowStroke.Color        = T.TextWhite
                            RowStroke.Transparency = 0
                            UpdateHeader(opt)
                            Dropdown.Open = false
                            TweenService:Create(DropdownFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, RowHeight)}):Play()
                            Callback(opt.Color, opt.Name)
                        end)

                    else
                        -- ── STANDARD TEXT ROW ─────────────────────────
                        local OptBtn = Instance.new("TextButton")
                        OptBtn.LayoutOrder      = i
                        OptBtn.Size             = UDim2.new(1, 0, 0, OptHeight)
                        OptBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
                        OptBtn.Text             = opt
                        OptBtn.TextColor3       = T.TextDark
                        OptBtn.Font             = Enum.Font.Gotham
                        OptBtn.TextSize         = FS(11)
                        OptBtn.Parent           = OptionHolder
                        Instance.new("UICorner", OptBtn).CornerRadius = UDim.new(0, 4)

                        OptBtn.MouseButton1Click:Connect(function()
                            if dropDisabled then return end
                            UpdateHeader(opt)
                            Dropdown.Open = false
                            TweenService:Create(DropdownFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, RowHeight)}):Play()
                            Callback(opt)
                        end)
                    end
                end
            end

            Header.MouseButton1Click:Connect(function()
                if dropDisabled then return end
                Dropdown.Open = not Dropdown.Open
                local targetH = Dropdown.Open and GetOpenHeight() or RowHeight
                TweenService:Create(DropdownFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Size = UDim2.new(1, 0, 0, targetH)}):Play()
            end)

            function Element:SetDisabled(state)
                dropDisabled  = state
                Header.Active = not state
                TweenService:Create(TitleLabel, TweenInfo.new(0.2), {TextColor3 = state and T.TextSecondary or T.TextPrimary}):Play()
                if SelectedLabel  then TweenService:Create(SelectedLabel,  TweenInfo.new(0.2), {TextTransparency       = state and 0.5 or 0}):Play() end
                if SelectedSwatch then TweenService:Create(SelectedSwatch, TweenInfo.new(0.2), {BackgroundTransparency = state and 0.5 or 0}):Play() end
                if SelectedName   then TweenService:Create(SelectedName,   TweenInfo.new(0.2), {TextTransparency       = state and 0.5 or 0}):Play() end
                if state and Dropdown.Open then
                    Dropdown.Open = false
                    TweenService:Create(DropdownFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, RowHeight)}):Play()
                end
            end

            function Element:SetOptions(newOptions)
                Options  = newOptions
                Selected = newOptions[1] and Normalise(newOptions[1])
                UpdateHeader(Selected)
                Dropdown.Open = false
                TweenService:Create(DropdownFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, RowHeight)}):Play()
                Refresh()
            end

            function Element:SetSelected(val)
                UpdateHeader(Normalise(val))
            end

            Refresh()
            return AttachTooltip(TitleLabel, Element)
        end

        return Tab
    end
    
    Window.Frame = MainFrame
    Window.Sidebar = Sidebar
    return Window
end

-- ============================================================
-- SCRIPT EXECUTION
-- ============================================================
local HubWindow = Library:CreateWindow()

local ShopTab        = HubWindow:CreateTab("Shop")
local ToolTab        = HubWindow:CreateTab("Tool")

local function LoadModule(ModuleName)
    local URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/Modules/%s.lua?t=%s",
        User, Repo, Branch, ModuleName, tick())
    local success, code = pcall(function() return game:HttpGet(URL) end)
    if success and code then
        local func = loadstring(code)
        if func then return func() end
    end
    warn("Failed to load module: " .. ModuleName)
end

local Theme = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/learnhtsd/lt2/refs/heads/main/Theme.lua"
))()

local LooseObjectTeleportModule = LoadModule("LooseObjectTeleport")
if LooseObjectTeleportModule and LooseObjectTeleportModule.Init then LooseObjectTeleportModule.Init(ToolTab, Library) end
Library:Notify("Loaded", "Loose Object Teleport", 2)

local ShopScript = LoadModule("Shop")
if ShopScript and ShopScript.Init then ShopScript.Init(ShopTab, LooseObjectTeleportModule) end
Library:Notify("Loaded", "Shop", 2)

Library:Notify("Dynxe LT2", "All modules loaded!", 5)
