# Dynxe LT2 Hub — UI Library Documentation

<div align="center">

![Version](https://img.shields.io/badge/version-v0.0.208-blue?style=for-the-badge)
![Lua](https://img.shields.io/badge/language-Lua-purple?style=for-the-badge)
![Platform](https://img.shields.io/badge/platform-Roblox-red?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)

**A modular, themeable Roblox GUI library for building feature-rich executor hubs.**

</div>

---

## Table of Contents

- [Overview](#overview)
- [Configuration](#configuration)
  - [Window Config](#window-config)
  - [Element Scale Config](#element-scale-config)
  - [Theme Config](#theme-config)
- [Library Setup](#library-setup)
  - [Creating a Window](#creating-a-window)
  - [Creating a Tab](#creating-a-tab)
- [UI Elements](#ui-elements)
  - [Section](#createSection)
  - [Row](#createrow)
  - [Action Button](#createaction)
  - [Toggle](#createtoggle)
  - [Slider](#createslider)
  - [Input Box](#createinput)
  - [Keybind](#createkeybind)
  - [Dropdown](#createdropdown)
  - [Info Box](#createinfobox)
  - [Image Selector](#createimageselector)
- [Tooltips](#tooltips)
- [Notifications](#notifications)
- [Module System](#module-system)
- [Asset / Image Helper](#asset--image-helper)
- [Scale Helpers](#scale-helpers)
- [Full Example](#full-example)

---

## Overview

The **Dynxe LT2 Hub** is a complete Roblox executor GUI library. It provides a draggable windowed interface with a sidebar tab system, a rich set of UI controls (toggles, sliders, dropdowns, keybinds, etc.), notifications, tooltips, and a remote module-loading system.

**Key Features:**

- Sidebar icon-based tab navigation
- Fully scalable elements via a single `Scale` config value
- Centralised theme colour palette — change one object to restyle everything
- Tooltip system attachable to any element
- Pop-up notification toasts
- Remote module loading from GitHub
- Automatic asset downloading and caching

---

## Configuration

All configuration lives at the top of the script in the `Config` table. Modify these values **before** any UI is built.

### Window Config

```lua
Config.Window = {
    Width        = 500,   -- Total window width in pixels
    Height       = 300,   -- Total window height in pixels
    SidebarWidth = 35,    -- Width of the left icon sidebar in pixels
}
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `Width` | `number` | `500` | Total pixel width of the hub window |
| `Height` | `number` | `300` | Total pixel height of the hub window |
| `SidebarWidth` | `number` | `35` | Pixel width of the left sidebar that holds tab icons |

---

### Element Scale Config

```lua
Config.Elements = {
    Scale = 0.75,   -- Multiplier applied to all element sizes & font sizes
}
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `Scale` | `number` | `0.75` | Global multiplier for element heights, padding, and font sizes. `1.0` = full size. Values below `1.0` make the UI more compact. |

> **Note:** Font sizes are clamped to a minimum of `8px` regardless of scale to prevent illegibility.

---

### Theme Config

```lua
Config.Theme = {
    Accent          = Color3.fromRGB(74,  120, 255),
    Background      = Color3.fromRGB(18,  18,  22),
    Surface         = Color3.fromRGB(24,  24,  29),
    SurfaceDeep     = Color3.fromRGB(35,  35,  42),
    Sidebar         = Color3.fromRGB(14,  14,  17),
    Stroke          = Color3.fromRGB(40,  40,  48),
    TextPrimary     = Color3.fromRGB(220, 220, 220),
    TextSecondary   = Color3.fromRGB(120, 120, 130),
    TextDark        = Color3.fromRGB(180, 180, 180),
    TextWhite       = Color3.fromRGB(255, 255, 255),
    Success         = Color3.fromRGB(45,  160, 75),
    Warning         = Color3.fromRGB(190, 120, 15),
    NotifBackground = Color3.fromRGB(24,  24,  29),
}
```

| Key | Role |
|-----|------|
| `Accent` | Blue highlight used on active elements, borders, fills |
| `Background` | Main window background |
| `Surface` | Card/element backgrounds |
| `SurfaceDeep` | Inset areas (slider tracks, button backgrounds) |
| `Sidebar` | Sidebar panel background |
| `Stroke` | Border and divider colour |
| `TextPrimary` | Element title text |
| `TextSecondary` | Muted/icon text |
| `TextDark` | Description and secondary body text |
| `TextWhite` | Header and active label text |
| `Success` | Green used for confirmed actions |
| `Warning` | Amber used for secure (confirm-required) actions |
| `NotifBackground` | Notification toast background |

---

## Library Setup

### Creating a Window

```lua
local HubWindow = Library:CreateWindow()
```

This bootstraps the entire GUI — creates the `ScreenGui`, the main draggable frame, the sidebar, content area, and notification container. The window is centred on screen and can be freely dragged.

**Returns:** `Window` — the top-level object used to create tabs.

| Property | Type | Description |
|----------|------|-------------|
| `Window.Frame` | `Frame` | The root MainFrame GuiObject |
| `Window.Sidebar` | `Frame` | The sidebar panel GuiObject |

---

### Creating a Tab

```lua
local MyTab = HubWindow:CreateTab("TabName")
```

Adds a new icon button to the sidebar and a corresponding scrollable content page. The first tab created is automatically activated.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `TabName` | `string` | The display name of the tab. Also used as the icon filename to fetch from GitHub (`/Icons/TabName.png`). The first character is used as a fallback text icon if the image fails to load. |

**Returns:** `Tab` — used to add elements to this tab's content page.

> **Icon Loading:** Icons are fetched from `https://raw.githubusercontent.com/{User}/{Repo}/{Branch}/Icons/{TabName}.png` and cached locally. If unavailable, the first letter of `TabName` is shown instead.

---

## UI Elements

All element creation methods are called on a `Tab` object (or a `Row` object for horizontal layouts). Every element that has a title label supports the [Tooltip](#tooltips) system via `:AddTooltip()`.

---

### `CreateSection`

Inserts a styled section header label into the tab. Used to visually group related elements.

```lua
Tab:CreateSection("SECTION NAME")
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `Name` | `string` | The section label text. Displayed in uppercase, accent colour. |

**Returns:** `nil`

**Example:**

```lua
PlayerTab:CreateSection("Movement")
```

---

### `CreateRow`

Creates a horizontal container. Any elements added to the returned `Row` object are laid out side-by-side and automatically sized to fill the row equally.

```lua
local MyRow = Tab:CreateRow()
MyRow:CreateToggle(...)
MyRow:CreateToggle(...)
```

**Returns:** `Row` — behaves identically to a `Tab` for element creation purposes.

> **Tip:** Rows are useful for putting two compact controls (e.g., two toggles) next to each other to save vertical space.

---

### `CreateAction`

Creates a labelled row with a clickable button on the right side. Supports an optional **Secure Mode** that requires a double-click confirmation before firing the callback.

```lua
local Element = Tab:CreateAction(Title, ButtonText, Callback, Secure)
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Title` | `string` | ✅ | Label text shown on the left of the row |
| `ButtonText` | `string` | ✅ | Text shown on the button |
| `Callback` | `function` | ✅ | Function called when the button is clicked (or confirmed if Secure) |
| `Secure` | `boolean` | ❌ | If `true`, a 🔒 badge is shown and the button requires a confirmation click within 3 seconds |

**Returns:** `Element`

**Element Methods:**

| Method | Parameters | Description |
|--------|-----------|-------------|
| `:SetText(NewText)` | `string` | Changes the button label text |
| `:SetDisabled(State)` | `boolean` | Enables (`false`) or disables (`true`) the button. Disabled buttons are visually faded and non-interactive. |
| `:AddTooltip(text)` | `string` | Attaches a hover tooltip to the title label |

**Example:**

```lua
local ResetAction = PlayerTab:CreateAction("Reset Character", "Reset", function()
    game.Players.LocalPlayer.Character:FindFirstChild("Humanoid").Health = 0
end)

-- Disable after use
ResetAction:SetDisabled(true)

-- Re-enable
ResetAction:SetDisabled(false)

-- Secure action requiring confirmation
local NukeAction = WorldTab:CreateAction("Nuke All Trees", "Execute", function()
    -- Only runs after confirmation click
    print("Confirmed!")
end, true)  -- true = secure mode
```

**Secure Mode Flow:**

1. First click → button turns amber and shows `"Confirm?"`
2. Second click within 3 seconds → fires `Callback`, button shows `"✓ Done"` briefly
3. No second click within 3 seconds → button resets automatically

---

### `CreateToggle`

Creates a labelled row with an animated on/off toggle switch.

```lua
local Element = Tab:CreateToggle(Title, Default, Callback)
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Title` | `string` | ✅ | Label text shown on the left |
| `Default` | `boolean` | ✅ | Starting state of the toggle (`true` = on, `false` = off) |
| `Callback` | `function(state: boolean)` | ✅ | Called every time the toggle changes, receives the new state |

**Returns:** `Element`

**Element Methods:**

| Method | Parameters | Description |
|--------|-----------|-------------|
| `:SetState(state)` | `boolean` | Programmatically sets the toggle to on or off without firing `Callback` |
| `:AddTooltip(text)` | `string` | Attaches a hover tooltip |

**Example:**

```lua
local SpeedToggle = PlayerTab:CreateToggle("Speed Boost", false, function(state)
    if state then
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 50
    else
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 16
    end
end)

-- Programmatically turn off
SpeedToggle:SetState(false)
```

---

### `CreateSlider`

Creates a labelled row with a draggable horizontal slider for numeric input.

```lua
local Element = Tab:CreateSlider(Title, Min, Max, Default, Callback, Decimals)
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Title` | `string` | ✅ | Label text shown above the slider |
| `Min` | `number` | ✅ | Minimum value |
| `Max` | `number` | ✅ | Maximum value |
| `Default` | `number` | ✅ | Starting value (must be between Min and Max) |
| `Callback` | `function(value: number)` | ✅ | Called continuously while dragging, receives the current value |
| `Decimals` | `number` | ❌ | Number of decimal places (default `0` = integers). Pass `1` for one decimal, `2` for two, etc. |

**Returns:** `Element`

**Element Methods:**

| Method | Parameters | Description |
|--------|-----------|-------------|
| `:SetValue(value)` | `number` | Programmatically sets the slider position without firing `Callback`. Value is clamped to Min/Max. |
| `:SetDisabled(state)` | `boolean` | Enables or disables slider interaction. Disabled state is shown by dimming the fill and labels. |
| `:AddTooltip(text)` | `string` | Attaches a hover tooltip |

**Example:**

```lua
-- Integer slider
local WalkSpeedSlider = PlayerTab:CreateSlider("Walk Speed", 16, 250, 16, function(value)
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = value
end)

-- Decimal slider (1 decimal place)
local GravitySlider = WorldTab:CreateSlider("Gravity", 0, 200, 196.2, function(value)
    game:GetService("Workspace").Gravity = value
end, 1)

-- Programmatic update
WalkSpeedSlider:SetValue(100)

-- Disable
WalkSpeedSlider:SetDisabled(true)
```

---

### `CreateInput`

Creates a labelled row with a text input box on the right side.

```lua
local Element = Tab:CreateInput(Title, Placeholder, Callback)
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Title` | `string` | ✅ | Label text on the left |
| `Placeholder` | `string` | ✅ | Grey placeholder text shown when the box is empty |
| `Callback` | `function(text: string)` | ✅ | Called when the input box loses focus, receives the current text |

**Returns:** `Element`

**Element Methods:**

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `:SetText(val)` | `string` | — | Programmatically sets the input box value |
| `:GetText()` | — | `string` | Returns the current text in the input box |
| `:AddTooltip(text)` | `string` | — | Attaches a hover tooltip |

**Example:**

```lua
local ServerInput = TeleportTab:CreateInput("Server ID", "Enter Job ID...", function(text)
    print("User entered:", text)
    -- Teleport logic here
end)

-- Read the value at any time
local currentValue = ServerInput:GetText()

-- Set a value programmatically
ServerInput:SetText("abc123-job-id")
```

---

### `CreateKeybind`

Creates a labelled row with a rebindable key button. Clicking the button enters listening mode and the next keyboard key or mouse button pressed becomes the new binding.

```lua
local Element = Tab:CreateKeybind(Title, Default, Callback)
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Title` | `string` | ✅ | Label text on the left |
| `Default` | `KeyCode` or `UserInputType` | ✅ | The default binding. Pass a `KeyCode` enum value (e.g., `Enum.KeyCode.RightShift`) or a `UserInputType` enum value |
| `Callback` | `function()` | ✅ | Called every time the bound key/button is pressed (only when the input is not processed by Roblox's core UI) |

**Returns:** `Element`

> Supports rebinding to any keyboard key, `MouseButton2`, or `MouseButton3`. `MouseButton1` is reserved for the rebind button itself and cannot be bound.

**Example:**

```lua
local MenuKeybind = SettingsTab:CreateKeybind("Toggle Menu", Enum.KeyCode.RightShift, function()
    -- Toggle hub visibility
    HubWindow.Frame.Visible = not HubWindow.Frame.Visible
end)

local NoclipKeybind = PlayerTab:CreateKeybind("Noclip", Enum.KeyCode.N, function()
    print("Noclip toggled")
end)
```

---

### `CreateDropdown`

Creates a labelled row with a collapsible dropdown menu for selecting one option from a list.

```lua
local Element = Tab:CreateDropdown(Title, Options, Default, Callback)
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Title` | `string` | ✅ | Label text on the left |
| `Options` | `table` (array of strings) | ✅ | List of selectable option strings |
| `Default` | `string` | ❌ | The option shown as selected by default. Falls back to `"Select..."` if `nil`. |
| `Callback` | `function(selected: string)` | ✅ | Called when an option is selected, receives the chosen string |

**Returns:** `Element`

**Element Methods:**

| Method | Parameters | Description |
|--------|-----------|-------------|
| `:AddTooltip(text)` | `string` | Attaches a hover tooltip to the title |

**Example:**

```lua
local BiomeDropdown = WorldTab:CreateDropdown(
    "Biome Select",
    {"Tropics", "Taiga", "Swamp", "Highlands", "Crook's Hollow"},
    "Tropics",
    function(selected)
        print("Selected biome:", selected)
        -- Teleport or world logic here
    end
)
```

---

### `CreateInfoBox`

Creates a styled information card — useful for displaying status, announcements, or contextual help. Supports an optional header with title, icon, and badge, plus a body text area.

```lua
-- Simple (legacy) form:
local InfoBox = Tab:CreateInfoBox("Title", "Description text here.")

-- Full config form:
local InfoBox = Tab:CreateInfoBox({
    Title       = "Status",
    Icon        = "ℹ",
    Badge       = "ACTIVE",
    BadgeColor  = Color3.fromRGB(45, 160, 75),
    Description = "Everything is running normally.",
})
```

**Config Table Fields:**

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `Title` | `string` | ❌ | Header title text |
| `Icon` | `string` | ❌ | Emoji or symbol shown to the left of the title |
| `Badge` | `string` | ❌ | Pill-shaped badge text shown on the right of the header |
| `BadgeColor` | `Color3` | ❌ | Background colour of the badge (defaults to `Theme.Success`) |
| `Description` | `string` | ❌ | Body text below the header. Supports `RichText` formatting. |

**Returns:** `InfoBox`

**InfoBox Methods:**

| Method | Parameters | Description |
|--------|-----------|-------------|
| `:SetTitle(text)` | `string` | Updates the header title text |
| `:SetBadge(text, color)` | `string`, `Color3?` | Updates the badge text and optionally its colour. Pass `""` to hide the badge. |
| `:SetDescription(text)` | `string` | Updates the body description text. Supports RichText. |
| `:SetAccentColor(color)` | `Color3` | Changes the top stripe colour and border stroke colour |

**Example:**

```lua
local StatusBox = HomeTab:CreateInfoBox({
    Title       = "Dynxe LT2",
    Icon        = "🌲",
    Badge       = "LOADED",
    BadgeColor  = Color3.fromRGB(45, 160, 75),
    Description = "All modules loaded successfully. Welcome back!",
})

-- Update at runtime
StatusBox:SetBadge("ERROR", Color3.fromRGB(200, 50, 50))
StatusBox:SetDescription("Module failed to load. Please rejoin.")
StatusBox:SetAccentColor(Color3.fromRGB(200, 50, 50))
```

---

### `CreateImageSelector`

Creates a horizontally-scrollable grid of image slots for selecting items (e.g., wood types, tools, items). Supports single or multi-select.

```lua
local Element = Tab:CreateImageSelector(Title, Config, Callback)
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Title` | `string` | ✅ | Label shown above the selector |
| `Config` | `table` | ❌ | Configuration table (see below) |
| `Callback` | `function(selected)` | ✅ | Called when a slot is clicked. In single-select mode receives the selected title/ID as a `string`. In multi-select mode receives a `table` of all selected titles/IDs. |

**Config Table Fields:**

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `MultiSelect` | `boolean` | `false` | Allow multiple slots to be selected simultaneously |
| `Rows` | `number` | `1` | Number of visible rows in the grid |
| `SlotSize` | `UDim2` | `UDim2.new(0, ES(70), 0, ES(70))` | Size of each image slot |

**Returns:** `Element`

**Element Methods:**

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `:AddSlot(ID, SlotTitle, SlotSubText)` | `string, string?, string?` | `ImageButton` | Adds an image slot to the grid. `ID` is a Roblox asset ID string. `SlotTitle` is optional text below the image. `SlotSubText` is optional green sub-label (e.g., price, rarity). |

**Example:**

```lua
local WoodSelector = WoodTab:CreateImageSelector("Select Wood Type", {
    MultiSelect = true,
    Rows        = 1,
}, function(selected)
    -- selected is a table when MultiSelect = true
    print("Selected woods:", table.concat(selected, ", "))
end)

WoodSelector:AddSlot("rbxassetid://1234567", "Oak",   "Common")
WoodSelector:AddSlot("rbxassetid://2345678", "Birch", "Common")
WoodSelector:AddSlot("rbxassetid://3456789", "Pine",  "Rare")
WoodSelector:AddSlot("rbxassetid://4567890", "Lava",  "Legendary")
```

---

## Tooltips

Any element returned by a `Create*` function (that has a title label) supports the `:AddTooltip()` method. Tooltips appear as a small floating label near the cursor when hovering over the `(?)` icon that is appended to the element title.

```lua
Element:AddTooltip("Hover text shown to the user.")
```

**Tooltip is chainable — attach immediately after creation:**

```lua
local MyToggle = Tab:CreateToggle("Noclip", false, function(state) end)
    :AddTooltip("Walk through walls. Disable before taking damage.")

local MySlider = Tab:CreateSlider("Walk Speed", 16, 500, 16, function(v) end)
    :AddTooltip("Default Roblox walk speed is 16.")
```

> **Internal:** Tooltips are powered by `Library.ShowTooltip(text)` and `Library.HideTooltip()`, which control a shared `TextLabel` positioned at the cursor. You can call these directly if needed for custom elements.

---

## Notifications

Display a temporary toast notification in the bottom-right corner of the screen.

```lua
Library:Notify(Title, Text, Duration)
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Title` | `string` | ✅ | Bold uppercase header text. Displayed in the accent colour. |
| `Text` | `string` | ✅ | Body message text. |
| `Duration` | `number` | ❌ | How long the notification stays visible in seconds. Defaults to `5`. |

**Example:**

```lua
Library:Notify("Module Loaded", "PlayerMovement has been initialised.", 4)
Library:Notify("Error", "Failed to connect to server.", 8)
Library:Notify("Success", "Teleport complete!", 3)
```

> Notifications slide in from below and fade out automatically. Multiple notifications stack vertically.

---

## Module System

The hub loads feature modules remotely from the GitHub repository at runtime. This keeps the main script small and allows modules to be updated independently.

### `LoadModule(ModuleName)`

```lua
local function LoadModule(ModuleName)
    local URL = string.format(
        "https://raw.githubusercontent.com/%s/%s/%s/Modules/%s.lua?t=%s",
        User, Repo, Branch, ModuleName, tick()
    )
    -- ...fetches, loadstrings, and returns the module table
end
```

Each module is expected to return a table with an `Init` function:

```lua
-- Example module structure (e.g., Modules/MyFeature.lua)
local MyFeature = {}

function MyFeature.Init(Tab, Library)
    Tab:CreateSection("My Feature")
    Tab:CreateToggle("Enable Thing", false, function(state)
        -- feature logic
    end)
end

return MyFeature
```

### Loading a Module

```lua
local MyModule = LoadModule("MyFeature")
if MyModule and MyModule.Init then
    MyModule.Init(TargetTab, Library)
end
```

### Built-in Modules

| Module Name | Target Tab | Description |
|-------------|-----------|-------------|
| `Home` | `HomeTab` | Welcome / status screen |
| `PlayerMovement` | `PlayerTab` | Walk speed, jump power, noclip, etc. |
| `FlashLight` | `PlayerTab` | Flashlight tool |
| `Teleport` | `TeleportTab` | Location teleports |
| `GhostSuite` | `BuildTab` | Build / ghost placement tools |
| `World` | `WorldTab` | World environment controls |
| `Settings` | `SettingsTab` | Hub configuration |
| `HardDragger` | `PlayerTab` | Item dragging utility |
| `WatchDog` | `ProtectionTab` | Anti-exploit monitoring |
| `AntiFling` | `ProtectionTab` | Prevents fling exploits |
| `AntiVoid` | `ProtectionTab` | Prevents void kills |
| `AntiRagdoll` | `ProtectionTab` | Prevents ragdoll exploits |
| `AntiAFK` | `ProtectionTab` | Auto AFK bypass |
| `LooseObjectTeleport` | `ToolTab` | Teleport loose world objects |
| `PlayPositionNotify` | `ToolTab` | Notifies of player positions |
| `TreeCam` | `WoodTab` | Camera helper for tree cutting |
| `Vehicle` | `VehicleTab` | Vehicle controls |
| `Plot` | `PlotTab` | Plot management |
| `AxeDupe` | `DuplicatetTab` | Axe duplication |
| `Tree` | `WoodTab` | Tree-cutting automation |
| `Shop` | `ShopTab` | Shop automation |

---

## Asset / Image Helper

```lua
getgenv().GetImage(folder, fileName)
```

Downloads and caches a remote image file from the GitHub repository, returning a usable asset path for `ImageLabel.Image`.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `folder` | `string` | Subfolder inside `Images/` on the repo. Pass `""` for the root Images folder. |
| `fileName` | `string` | The filename including extension (e.g., `"MyIcon.png"`) |

**Returns:** `string` — a `getcustomasset(...)` path, or the placeholder asset ID if the file is unavailable.

**Image URL pattern:**
```
https://raw.githubusercontent.com/{User}/{Repo}/{Branch}/Images/{folder}/{fileName}
```

**Example:**

```lua
local myIcon = GetImage("UI", "logout.png")
local img = Instance.new("ImageLabel")
img.Image = myIcon
```

> If the file is missing remotely, a placeholder image is downloaded and shown instead, with a `warn` printed to the output.

---

## Scale Helpers

Two internal helper functions are used throughout the library to keep all sizes proportional to `Config.Elements.Scale`:

```lua
local function ES(n) return math.round(n * Config.Elements.Scale) end  -- Element Scale
local function FS(n) return math.max(8, math.round(n * Config.Elements.Scale)) end  -- Font Scale
```

| Helper | Purpose |
|--------|---------|
| `ES(n)` | Scales pixel sizes, heights, padding, and offsets |
| `FS(n)` | Scales font sizes, with a hard minimum of `8px` |

When creating custom elements inside modules, use these helpers if you want your elements to respect the global scale setting.

---

## Full Example

```lua
-- Load the library (assumes the main script is already executed)
local HubWindow = Library:CreateWindow()

-- ── Create tabs ─────────────────────────────────────────────
local PlayerTab = HubWindow:CreateTab("Player")
local WorldTab  = HubWindow:CreateTab("World")

-- ── Player Tab ───────────────────────────────────────────────
PlayerTab:CreateSection("Movement")

local SpeedSlider = PlayerTab:CreateSlider("Walk Speed", 16, 250, 16, function(value)
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = value
end)
SpeedSlider:AddTooltip("Default is 16. Maximum recommended is 250.")

local JumpSlider = PlayerTab:CreateSlider("Jump Power", 50, 300, 50, function(value)
    game.Players.LocalPlayer.Character.Humanoid.JumpPower = value
end)

PlayerTab:CreateSection("Cheats")

local NoclipToggle = PlayerTab:CreateToggle("Noclip", false, function(state)
    print("Noclip:", state)
end):AddTooltip("Walk through solid objects.")

local ResetAction = PlayerTab:CreateAction("Reset Character", "Reset", function()
    game.Players.LocalPlayer.Character.Humanoid.Health = 0
end, true)  -- Secure mode — requires confirmation

-- ── World Tab ────────────────────────────────────────────────
WorldTab:CreateSection("Environment")

local GravitySlider = WorldTab:CreateSlider("Gravity", 0, 400, 196.2, function(value)
    workspace.Gravity = value
end, 1)

WorldTab:CreateDropdown(
    "Time of Day",
    {"Morning", "Noon", "Sunset", "Night"},
    "Noon",
    function(selected)
        print("Time set to:", selected)
    end
)

local StatusBox = WorldTab:CreateInfoBox({
    Title       = "World Status",
    Icon        = "🌍",
    Badge       = "NORMAL",
    BadgeColor  = Color3.fromRGB(45, 160, 75),
    Description = "All world parameters are at default values.",
})

-- ── Notifications ─────────────────────────────────────────────
Library:Notify("Hub Loaded", "Welcome! All systems operational.", 5)
```

---

## Repository Structure

```
lt2/
├── Icons/               # Tab icon PNGs (fetched by tab name)
│   ├── Home.png
│   ├── Player.png
│   └── ...
├── Images/              # Images used by GetImage()
│   ├── Placeholder.png
│   └── ...
├── Modules/             # Remote feature modules
│   ├── Home.lua
│   ├── PlayerMovement.lua
│   └── ...
├── Theme.lua            # Remote theme overrides
└── README.md
```

---

<div align="center">

*Dynxe LT2 Hub — Built for Lumber Tycoon 2*

</div>
