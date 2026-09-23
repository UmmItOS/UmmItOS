-- Hyprland's own features. Every bind carries a description: the shell's
-- cheat sheet (Super+/) lists binds from `hyprctl binds`, grouped by the
-- description's prefix, and one without a description is missing from it.

local mainMod = "SUPER"

-- The description starts with the cheat sheet group it is listed under.
local function bind(group, keys, action, description, opts)
    opts = opts or {}
    opts.description = group .. ": " .. description
    hl.bind(keys, action, opts)
end

bind("Window", mainMod .. " + C", hl.dsp.window.close(), "Close active window")
bind("Window", mainMod .. " + V", hl.dsp.window.float(), "Toggle window floating")
bind("Window", mainMod .. " + J", hl.dsp.window.swap({ next = true }), "Swap with next window")

-- Move focus with mainMod + arrow keys
bind("Window", mainMod .. " + left", hl.dsp.focus({ direction = "left" }), "Focus window to the left")
bind("Window", mainMod .. " + right", hl.dsp.focus({ direction = "right" }), "Focus window to the right")
bind("Window", mainMod .. " + up", hl.dsp.focus({ direction = "up" }), "Focus window above")
bind("Window", mainMod .. " + down", hl.dsp.focus({ direction = "down" }), "Focus window below")

-- Switch workspaces with mainMod + [0-9]; move the active window with SHIFT
for i = 1, 10 do
    local key = tostring(i % 10)
    bind("Workspace", mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }), "Switch to workspace " .. i)
    bind("Workspace", mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }),
        "Move active window to workspace " .. i)
end

-- Magic hidden workspace
bind("Workspace", mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"), "Toggle special workspace")
bind("Workspace", mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic", follow = true }),
    "Move active window to special workspace")

-- Scroll through existing workspaces with mainMod + scroll
bind("Workspace", mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Next workspace")
bind("Workspace", mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "Previous workspace")

-- Move/resize windows with mainMod + LMB/RMB and dragging
bind("Window", mainMod .. " + mouse:272", hl.dsp.window.drag(), "Drag to move window", { mouse = true })
bind("Window", mainMod .. " + mouse:273", hl.dsp.window.resize(), "Drag to resize window", { mouse = true })

-- Resize the active window, repeating while held
bind("Window", "ALT + right", hl.dsp.window.resize({ x = 5, y = 0, relative = true }), "Resize window right", { repeating = true })
bind("Window", "ALT + left", hl.dsp.window.resize({ x = -5, y = 0, relative = true }), "Resize window left", { repeating = true })
bind("Window", "ALT + up", hl.dsp.window.resize({ x = 0, y = -5, relative = true }), "Resize window up", { repeating = true })
bind("Window", "ALT + down", hl.dsp.window.resize({ x = 0, y = 5, relative = true }), "Resize window down", { repeating = true })
