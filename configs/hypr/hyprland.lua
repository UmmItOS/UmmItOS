-- UmmItOS Hyprland config. Each part lives in hyprland/*.lua; `require` runs
-- every module in its own scope, so an error in one does not stop the rest.
-- post-install.sh rewrites the first hl.monitor line below; keep it one line.

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

require("hyprland.env")
require("hyprland.autostart")
require("hyprland.keybinds")
require("hyprland.shortcuts")
require("hyprland.media-keys")
require("hyprland.appearance")
require("hyprland.animations")
require("hyprland.input")
require("hyprland.misc")
require("hyprland.plugins")
require("hyprland.debug")
require("hyprland.permissions")
