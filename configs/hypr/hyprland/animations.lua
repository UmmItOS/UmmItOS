hl.config({ animations = { enabled = true } })

-- Arrives fast, overshoots clearly, then settles.
hl.curve("land", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.15 } } })
-- Decelerates to a stop with no bounce, for fades.
hl.curve("glide", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
-- Leaves with a small pull back first, then away.
hl.curve("leave", { type = "bezier", points = { { 0.36, 0 }, { 0.66, -0.3 } } })
hl.curve("linear", { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })

local function animate(leaf, speed, curve, style)
    hl.animation({ leaf = leaf, enabled = true, speed = speed, bezier = curve, style = style })
end

animate("windowsIn", 7, "land", "popin 60%")
animate("windowsOut", 5, "leave", "popin 70%")
animate("windowsMove", 6, "land", "slide")

animate("fadeIn", 6, "glide")
animate("fadeOut", 5, "glide")
animate("fadeSwitch", 6, "glide")
animate("fadeDim", 6, "glide")

-- The shell's own layers (ummitos-*) are no_anim and animate themselves;
-- this is for everyone else's.
animate("layersIn", 5, "land", "popin 75%")
animate("layersOut", 4, "leave", "popin 80%")
animate("fadeLayers", 4, "glide")

animate("workspaces", 7, "land", "slidefade 30%")
animate("specialWorkspace", 6, "land", "slidefadevert 40%")

animate("border", 1, "linear")
animate("borderangle", 50, "linear", "loop")
