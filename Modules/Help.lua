local HelpModule = {}

-- ============================================================
-- HELP MODULE  —  Dynxe LT2
-- Uses Tab:CreateInfoBox() to render categorised help cards.
-- Add this tab in main.lua:
--   local HelpTab = HubWindow:CreateTab("Help")
--   ...
--   local HelpModule = LoadModule("Help")
--   if HelpModule and HelpModule.Init then HelpModule.Init(HelpTab) end
-- ============================================================

function HelpModule.Init(Tab)

    -- ══════════════════════════════════════════════════════════
    -- Duplcation
    -- ══════════════════════════════════════════════════════════
    Tab:CreateSection("Duplicating")

    local selBox = Tab:CreateInfoBox()
    selBox:AddText("will be added soon", { Bold = true, Size = 13 })
    selBox:AddDivider()
    selBox:AddText("will be added soon", { Size = 11, Opacity = 0.85, Wrap = true })
    selBox:AddText("will be added soon", { Size = 11, Opacity = 0.85, Wrap = true })
    selBox:AddText("will be added soon", { Size = 11, Opacity = 0.85, Wrap = true })
    selBox:AddText("will be added soon", { Size = 11, Opacity = 0.85, Wrap = true })

  
    -- ══════════════════════════════════════════════════════════
    -- LOOSE OBJECT TELEPORT
    -- ══════════════════════════════════════════════════════════
    Tab:CreateSection("Loose Object Teleport (LOT)")

    local selBox = Tab:CreateInfoBox()
    selBox:AddText("Selection Modes", { Bold = true, Size = 13 })
    selBox:AddDivider()
    selBox:AddText("Click Selection  —  Left-click any loose object to add it to the queue. Click it again to remove it.", { Size = 11, Opacity = 0.85, Wrap = true })
    selBox:AddText("Group Selection  —  Left-click one object to select every identical object you own on the map at once.", { Size = 11, Opacity = 0.85, Wrap = true })
    selBox:AddText("Lasso Tool  —  Click and drag a rectangle on-screen. Every object inside the box is toggled in / out of the queue.", { Size = 11, Opacity = 0.85, Wrap = true })
    selBox:AddText("Keep Selection After TP  —  When on, the queue is not cleared after a teleport so you can move the same objects repeatedly.", { Size = 11, Opacity = 0.85, Wrap = true })

    local tpBox = Tab:CreateInfoBox()
    tpBox:AddText("Teleporting", { Bold = true, Size = 13 })
    tpBox:AddDivider()
    tpBox:AddText("Press Start in the Teleport Selection row to move all queued objects to your feet.", { Size = 11, Opacity = 0.85, Wrap = true })
    tpBox:AddText("While a batch is running the button changes to Stop — press it to cancel the remaining jobs.", { Size = 11, Opacity = 0.85, Wrap = true })
    tpBox:AddText("Ownership Timeout  —  How long (in seconds) the script fires the ownership remote before giving up and moving the object anyway. Raise this on laggy servers.", { Size = 11, Opacity = 0.85, Wrap = true })

    local stackBox = Tab:CreateInfoBox()
    stackBox:AddText("Sort / Stack Mode", { Bold = true, Size = 13 })
    stackBox:AddDivider()
    stackBox:AddText("Select identical objects, configure X / Y / Z counts, then press Start under Sorting.", { Size = 11, Opacity = 0.85, Wrap = true })
    stackBox:AddText("A blue ghost preview follows your cursor. Move your mouse to the desired drop point and left-click to place.", { Size = 11, Opacity = 0.85, Wrap = true })
    stackBox:AddText("R  —  Rotate the stack 90° on the Y-axis (horizontal spin) before placing.", { Size = 11, Opacity = 0.85, Wrap = true })
    stackBox:AddText("The stack fills columns (X), then rows (Z), then layers upward (Y) so it always grows naturally from the ground.", { Size = 11, Opacity = 0.85, Wrap = true })

    -- ══════════════════════════════════════════════════════════
    -- TREE / WOOD
    -- ══════════════════════════════════════════════════════════
    Tab:CreateSection("Wood & Trees")

    local treeBox = Tab:CreateInfoBox()
    treeBox:AddText("Auto-Tree", { Bold = true, Size = 13 })
    treeBox:AddDivider()
    treeBox:AddText("Pick a tree class from the dropdown, then press Start. The script teleports you beside the tallest available tree of that type and fires the cut remote until it falls.", { Size = 11, Opacity = 0.85, Wrap = true })
    treeBox:AddText("Press Stop at any time to cancel the chop and return you to where you were standing.", { Size = 11, Opacity = 0.85, Wrap = true })
    treeBox:AddText("Logs are automatically pulled to your position after the tree falls.", { Size = 11, Opacity = 0.85, Wrap = true })
    treeBox:AddText("The axe currently in your hand (or first in your Backpack) is used — no manual equip required.", { Size = 11, Opacity = 0.85, Wrap = true })

    local logBox = Tab:CreateInfoBox()
    logBox:AddText("Log Management", { Bold = true, Size = 13 })
    logBox:AddDivider()
    logBox:AddText("Teleport All Logs To Me  —  Finds every log you own across the map and pulls them to your feet one by one.", { Size = 11, Opacity = 0.85, Wrap = true })
    logBox:AddText("Sell All Logs/Trees  —  Unanchors any standing trees you own, then teleports every log and wood section to the sawmill sell point.", { Size = 11, Opacity = 0.85, Wrap = true })
    logBox:AddText("Click To Sell (Planks)  —  Hover over one of your planks and left-click. The plank is teleported directly to the sell conveyor.", { Size = 11, Opacity = 0.85, Wrap = true })

    -- ══════════════════════════════════════════════════════════
    -- PROTECTION
    -- ══════════════════════════════════════════════════════════
    Tab:CreateSection("Protection")

    local protBox = Tab:CreateInfoBox()
    protBox:AddText("Anti-Cheats & Safeguards", { Bold = true, Size = 13 })
    protBox:AddDivider()
    protBox:AddText("Anti-Fling  —  Prevents other players from using fling exploits to launch your character.", { Size = 11, Opacity = 0.85, Wrap = true })
    protBox:AddText("Anti-Void  —  Catches your character if it falls below the map and returns it to a safe height.", { Size = 11, Opacity = 0.85, Wrap = true })
    protBox:AddText("Anti-Ragdoll  —  Stops ragdoll states from being forced on your character by other players.", { Size = 11, Opacity = 0.85, Wrap = true })
    protBox:AddText("Anti-AFK  —  Sends periodic inputs so the server does not kick you for inactivity.", { Size = 11, Opacity = 0.85, Wrap = true })
end

return HelpModule
