hl.config({ animations = { enabled = true } })

-- The shell's own motion (Theme.qml curve and duration), so windows and the shell move alike.
-- Arrives quickly, overshoots a little, then settles (expressiveDefaultSpatial).
hl.curve("spatial", { type = "bezier", points = { { 0.38, 1.21 }, { 0.22, 1 } } })
-- Decelerates to a stop, for things arriving (emphasizedDecel).
hl.curve("decel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
-- Speeds up as it leaves, for things going away (emphasizedAccel).
hl.curve("accel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("linear", { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

-- Speed is in tenths of a second: 5 is the shell's 500 ms, 3.5 its 350 ms, 2 its 200 ms.
local function animate(leaf, speed, curve, style)
    hl.animation({ leaf = leaf, enabled = true, speed = speed, bezier = curve, style = style })
end

animate("windowsIn", 5, "spatial", "popin 90%")
animate("windowsOut", 3.5, "accel", "popin 90%")
animate("windowsMove", 5, "spatial", "slide")

animate("fadeIn", 2, "decel")
animate("fadeOut", 1.5, "accel")
animate("fadeSwitch", 3, "decel")
animate("fadeDim", 3, "decel")

-- The shell's own layers (ummitos-*) are no_anim and animate themselves;
-- this is for everyone else's.
animate("layersIn", 5, "spatial", "popin 94%")
animate("layersOut", 3.5, "accel", "popin 94%")
animate("fadeLayers", 2, "decel")

animate("workspaces", 5, "spatial", "slidefade 20%")
animate("specialWorkspace", 5, "spatial", "slidefadevert 20%")

animate("border", 1, "linear")
animate("borderangle", 50, "linear", "loop")
