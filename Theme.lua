-- [[ THEME SETTINGS ]]
local Theme = {
    MainBG      = Color3.fromRGB(20, 20, 30),
    RowBG       = Color3.fromRGB(30, 30, 45),
    SidebarBG   = Color3.fromRGB(13, 13, 20),
    AccentBlue  = Color3.fromRGB(30, 120, 255),
    FilledBtn   = Color3.fromRGB(20, 90, 210),
    Text        = Color3.fromRGB(255, 255, 255),
    SubText     = Color3.fromRGB(180, 180, 195),
    Border      = Color3.fromRGB(40, 40, 60),
    DropShadow  = Color3.fromRGB(8, 8, 14),     -- Darker tint for DropShadow text
}

-- [[ SCALE SETTINGS ]]
-- 1.0 = default | 1.1 = 10% bigger | 0.9 = 10% smaller
local Scale = {
    UIScale = .8,
}

-- [[ FONT SETTINGS ]]
-- Options: GothamMedium, GothamBold, Gotham, Montserrat,
--          SourceSansPro, SourceSansSemibold, RobotoMono, Ubuntu
local Fonts = {
    Body   = Enum.Font.GothamMedium,
    Bold   = Enum.Font.GothamBold,
    Button = Enum.Font.GothamBold,
}

-- [[ TEXT SIZE SETTINGS ]]
-- Offset is additive on top of LT2's existing sizes.
-- 0 = no change | 2 = slightly bigger | -2 = slightly smaller
local TextSizes = {
    Offset     =  0,
    SectionMin = 13,
    BodyMin    = 12,
    ButtonMin  = 12,
}

-- =====================================================================

local Player    = game:GetService("Players").LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Tracks elements we're already watching to avoid duplicate connections
local watching = {}

local function ApplyUIScale(screenGui)
    if not screenGui:IsA("ScreenGui") then return end
    local existing = screenGui:FindFirstChildOfClass("UIScale")
    if existing then
        existing.Scale = Scale.UIScale
    else
        local s       = Instance.new("UIScale")
        s.Scale       = Scale.UIScale
        s.Parent      = screenGui
    end
end

-- =====================================================================
-- Core theming logic — returns a function that re-applies this element's
-- specific theme so we can call it both now and from a watcher.
-- =====================================================================
local function BuildApplier(obj)
    if obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
        local nameLower = obj.Name:lower()
        local color

        if nameLower:match("sidebar") or nameLower:match("nav") then
            color = Theme.SidebarBG
        elseif nameLower:match("shadow") or nameLower:match("drop") then
            color = Color3.fromRGB(0, 0, 0)
        elseif obj.Name == "Main" or nameLower:match("container")
            or nameLower:match("window") or nameLower:match("panel") then
            color = Theme.MainBG
        elseif nameLower:match("row") or nameLower:match("item")
            or nameLower:match("entry") or nameLower:match("cell") then
            color = Theme.RowBG
        else
            color = Theme.MainBG
        end

        local isShadow = nameLower:match("shadow") or nameLower:match("drop")

        return function()
            obj.BorderSizePixel = 0
            obj.BackgroundColor3 = color
            if isShadow then obj.BackgroundTransparency = 0.6 end
        end

    elseif obj:IsA("TextButton") then
        local nameLower = obj.Name:lower()
        local textLower = obj.Text and obj.Text:lower() or ""
        local bgColor, textColor, bgTransparency

        if textLower == "tp" or textLower == "plot" then
            bgColor = Theme.FilledBtn
            textColor = Theme.Text
            bgTransparency = 0
        elseif textLower:match("select") or nameLower:match("select")
            or nameLower:match("teleport") or textLower:match("teleport")
            or nameLower:match("^tp$") then
            bgColor = Color3.fromRGB(0, 0, 0)
            textColor = Theme.AccentBlue
            bgTransparency = 1
        else
            bgColor = Theme.RowBG
            textColor = Theme.Text
            bgTransparency = 0
        end

        return function()
            obj.BorderSizePixel = 0
            obj.Font = Fonts.Button
            obj.TextSize = math.max(TextSizes.ButtonMin, obj.TextSize) + TextSizes.Offset
            obj.BackgroundColor3 = bgColor
            obj.BackgroundTransparency = bgTransparency
            obj.TextColor3 = textColor
        end

    elseif obj:IsA("ImageButton") then
        return function()
            obj.BackgroundColor3 = Theme.SidebarBG
            obj.BackgroundTransparency = 0
            obj.BorderSizePixel = 0
        end

    elseif obj:IsA("TextLabel") then
        local nameLower = obj.Name:lower()
        local textVal   = obj.Text or ""

        -- DropShadow label — darker than everything else
        if nameLower == "dropshadow" or nameLower:match("drop_shadow") then
            return function()
                obj.BackgroundTransparency = 1
                obj.TextColor3 = Theme.DropShadow
                obj.Font = Fonts.Body
            end
        end

        local isHeader = nameLower:match("section") or nameLower:match("heading")
            or nameLower:match("header") or nameLower:match("title")
            or (textVal == textVal:upper() and #textVal > 2)
            or obj.TextSize >= 18

        local isSub = nameLower:match("sub") or nameLower:match("hint")
            or nameLower:match("desc")

        local textColor = isHeader and Theme.AccentBlue
                       or isSub    and Theme.SubText
                       or Theme.Text
        local font      = isHeader and Fonts.Bold or Fonts.Body
        local minSize   = isHeader and TextSizes.SectionMin or TextSizes.BodyMin

        return function()
            obj.BackgroundTransparency = 1
            obj.TextColor3 = textColor
            obj.Font = font
            obj.TextSize = math.max(minSize, obj.TextSize) + TextSizes.Offset
        end

    elseif obj:IsA("ImageLabel") then
        return function()
            obj.BackgroundTransparency = 1
        end
    end

    return nil
end

-- =====================================================================
-- Theme an object and attach a property-change watcher so that if LT2
-- resets the color we re-apply — but ONLY when LT2 resets it, not
-- during normal interaction/hover states.
-- =====================================================================
local function ThemeAndWatch(obj)
    if watching[obj] then return end

    local applier = BuildApplier(obj)
    if not applier then return end

    watching[obj] = true
    applier()

    -- Guard flag — prevents our own apply() from triggering the watcher
    local reapplying = false

    local function onReset()
        if reapplying then return end
        -- Small yield so hover/click animations can finish their own
        -- color change before we check whether it needs correcting.
        task.delay(0.15, function()
            if not obj or not obj.Parent then return end
            reapplying = true
            applier()
            reapplying = false
        end)
    end

    -- Watch the properties most commonly reset by LT2
    if obj:IsA("GuiObject") then
        obj:GetPropertyChangedSignal("BackgroundColor3"):Connect(onReset)
    end
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        obj:GetPropertyChangedSignal("TextColor3"):Connect(onReset)
        obj:GetPropertyChangedSignal("Font"):Connect(onReset)
    end

    -- Clean up our reference when the object is destroyed
    obj.Destroying:Connect(function()
        watching[obj] = nil
    end)
end

local function ThemeAll(parent)
    -- Scale any ScreenGuis at the top level
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("ScreenGui") then ApplyUIScale(child) end
    end
    for _, child in ipairs(parent:GetDescendants()) do
        ThemeAndWatch(child)
    end
end

-- Apply to newly added UI (popups, shop menus, etc.)
PlayerGui.DescendantAdded:Connect(function(descendant)
    task.wait(0.1) -- Let LT2 finish setting its defaults first
    ThemeAndWatch(descendant)
    if descendant:IsA("ScreenGui") then
        ApplyUIScale(descendant)
    end
end)

print("[DynxeTheme] Applying dark navy theme...")
ThemeAll(PlayerGui)

return true
