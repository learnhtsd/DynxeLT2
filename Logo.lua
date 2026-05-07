-- [[ BRAND MODULE ]] --
-- Auto-spawns a 3D Dynxe logo bar in the workspace

local BrandModule = {}

local TweenService = game:GetService("TweenService")

local THEME = {
    Accent      = Color3.fromRGB(74,  120, 255),
    Background  = Color3.fromRGB(18,  18,  22),
    Surface     = Color3.fromRGB(24,  24,  29),
    TextWhite   = Color3.fromRGB(255, 255, 255),
    TextPrimary = Color3.fromRGB(220, 220, 220),
    Stroke      = Color3.fromRGB(40,  40,  48),
}

function BrandModule.Init(version, position, rotation, width, height)
    local VERSION  = version  or "v0.0.272"
    local POSITION = position or Vector3.new(43.5, 18, 55.3)
    local ROTATION = rotation or Vector3.new(0, -105, 0)
    local BAR_W    = width    or 60
    local BAR_H    = height   or 20
    local BAR_D    = BAR_W * 0.04

    -- Clean up any previous instance
    local existing = workspace:FindFirstChild("DynxeBrand")
    if existing then existing:Destroy() end

    local rootCF = CFrame.new(POSITION)
        * CFrame.Angles(
            math.rad(ROTATION.X),
            math.rad(ROTATION.Y),
            math.rad(ROTATION.Z)
        )

    local Model = Instance.new("Model")
    Model.Name = "DynxeBrand"

    local function MakePart(name, size, color, material)
        local p = Instance.new("Part")
        p.Name          = name
        p.Size          = size
        p.Color         = color
        p.Material      = material or Enum.Material.SmoothPlastic
        p.Anchored      = true
        p.CanCollide    = false
        p.CastShadow    = false
        p.TopSurface    = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent        = Model
        return p
    end

    local function MakeLabel(cf, size, text, font, color, xAlign)
        local p = MakePart("Label", size, Color3.new())
        p.Transparency = 1
        p.CFrame       = cf

        local sg = Instance.new("SurfaceGui", p)
        sg.Face           = Enum.NormalId.Front
        sg.SizingMode     = Enum.SurfaceGuiSizingMode.PixelsPerStud
        sg.PixelsPerStud  = 50
        sg.AlwaysOnTop    = false
        sg.LightInfluence = 0

        local lbl = Instance.new("TextLabel", sg)
        lbl.Size                   = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text                   = text
        lbl.Font                   = font
        lbl.TextScaled             = true
        lbl.TextColor3             = color
        lbl.TextXAlignment         = xAlign

        local pad = Instance.new("UIPadding", lbl)
        pad.PaddingLeft  = UDim.new(0, 10)
        pad.PaddingRight = UDim.new(0, 10)
    end

    -- ── Main bar ──────────────────────────────────────────────────
    local Bar = MakePart("Bar", Vector3.new(BAR_W, BAR_H, BAR_D), THEME.Background)
    Bar.CFrame = rootCF

    -- ── Accent side caps ──────────────────────────────────────────
    local capSize = Vector3.new(0.18, BAR_H, BAR_D + 0.04)
    local CapL = MakePart("CapLeft",  capSize, THEME.Accent, Enum.Material.Neon)
    local CapR = MakePart("CapRight", capSize, THEME.Accent, Enum.Material.Neon)
    CapL.CFrame = rootCF * CFrame.new(-(BAR_W / 2 + 0.09), 0, -0.02)
    CapR.CFrame = rootCF * CFrame.new( (BAR_W / 2 + 0.09), 0, -0.02)

    -- ── Bottom accent strip ───────────────────────────────────────
    local Strip = MakePart("AccentStrip", Vector3.new(BAR_W, 0.18, BAR_D + 0.04), THEME.Accent, Enum.Material.Neon)
    Strip.CFrame = rootCF * CFrame.new(0, -(BAR_H / 2 + 0.09), -0.02)

    -- ── Layout constants ──────────────────────────────────────────
    local FRONT_Z = -(BAR_D / 2 + 0.05)
    local TOP_Y   = BAR_H / 2
    local HDR_H   = BAR_H * 0.28
    local HDR_Y   = TOP_Y - HDR_H / 2 - BAR_H * 0.04
    local HALF_W  = BAR_W / 2 - 0.2

    -- ── Version (left side of header) ─────────────────────────────
    MakeLabel(
        rootCF * CFrame.new(-(HALF_W / 2), HDR_Y, FRONT_Z),
        Vector3.new(HALF_W, HDR_H * 0.65, 0.1),
        VERSION,
        Enum.Font.Gotham,
        THEME.Accent,
        Enum.TextXAlignment.Left
    )

    -- ── "Dynxe" (right side of header) ────────────────────────────
    MakeLabel(
        rootCF * CFrame.new( (HALF_W / 2), HDR_Y, FRONT_Z),
        Vector3.new(HALF_W, HDR_H, 0.1),
        "Dynxe",
        Enum.Font.GothamBold,
        THEME.TextWhite,
        Enum.TextXAlignment.Right
    )

    -- ── Divider strip below the header ────────────────────────────
    local DIV_Y   = HDR_Y - HDR_H / 2 - BAR_H * 0.04
    local DIV_H   = BAR_H * 0.022
    local Divider = MakePart("Divider", Vector3.new(BAR_W * 0.92, DIV_H, 0.06), THEME.Stroke)
    Divider.CFrame = rootCF * CFrame.new(0, DIV_Y, FRONT_Z)

    -- ── Thank-you message ─────────────────────────────────────────
    local MSG_Y = DIV_Y - DIV_H / 2 - (BAR_H * 0.28)
    local MSG_H = BAR_H * 0.50
    MakeLabel(
        rootCF * CFrame.new(0, MSG_Y, FRONT_Z),
        Vector3.new(BAR_W * 0.92, MSG_H, 0.1),
        "Thank you for using Dynxe!",
        Enum.Font.GothamMedium,
        THEME.TextPrimary,
        Enum.TextXAlignment.Center
    )

    Model.PrimaryPart = Bar
    Model.Parent      = workspace

    -- ── Neon pulse ────────────────────────────────────────────────
    task.spawn(function()
        while Model and Model.Parent do
            TweenService:Create(Strip, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Color = Color3.fromRGB(100, 150, 255)
            }):Play()
            task.wait(1.4)
            TweenService:Create(Strip, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Color = THEME.Accent
            }):Play()
            task.wait(1.4)
        end
    end)

    return Model
end

return BrandModule
