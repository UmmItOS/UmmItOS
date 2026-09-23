-- Shortcuts for apps, the shell's surfaces and utilities.

local mainMod = "SUPER"

-- The description starts with the cheat sheet group it is listed under.
local function bind(group, keys, action, description, opts)
    opts = opts or {}
    opts.description = group .. ": " .. description
    hl.bind(keys, action, opts)
end

local function run(cmd)
    return hl.dsp.exec_cmd(cmd)
end

local function shell(target, fn)
    return run("qs -c ummitos ipc call " .. target .. " " .. fn)
end

bind("Apps", mainMod .. " + T", run("kitty"), "Launch terminal (kitty)")
bind("Apps", mainMod .. " + E", run("kitty -e yazi $HOME"), "Launch file manager (yazi)")
bind("Shell", mainMod .. " + Return", shell("launcher", "apps"), "Application launcher")
bind("Shell", mainMod .. " + X", shell("session", "toggle"), "Session menu")
bind("Shell", mainMod .. " + slash", shell("cheatsheet", "toggle"), "Keybind cheat sheet")
bind("Shell", mainMod .. " + L", shell("lock", "lock"), "Lock screen")
bind("Shell", "ALT + V", shell("launcher", "clipboard"), "Clipboard manager")
bind("Shell", "ALT + W", shell("wallpaper", "toggle"), "Wallpaper picker")
bind("Utilities", "ALT + E", run("smile"), "Emoji picker (Smile)")
bind("Utilities", "ALT + P", run("bash ~/script/hypr/hyprpicker/hyprpicker.sh"), "Color picker (Hyprpicker)")
bind("Utilities", "ALT + O", run("woomer"), "Screen magnifier (woomer)")
bind("Utilities", mainMod .. " + SHIFT + R", run("bash ~/script/misc/wf-recorder.sh"), "Start/stop screen recording")
bind("Apps", mainMod .. " + SHIFT + Return", run("kitty -e ~/script/misc/update.sh"), "Upgrade UmmItOS")

-- Screenshots, drawn by the shell
bind("Utilities", mainMod .. " + Print", shell("screenshot", "window"), "Screenshot active window")
bind("Utilities", "Print", shell("screenshot", "screen"), "Screenshot full screen")
bind("Utilities", "SHIFT + Print", shell("screenshot", "toggle"), "Screenshot region")
-- The same shot without Print, which laptops often put behind Fn.
bind("Utilities", mainMod .. " + SHIFT + W", shell("screenshot", "window"), "Screenshot a window")

-- Alt+Tab reaches the shell through the global-shortcuts protocol rather than
-- a keybind, so the switcher can see Alt released and commit on its own.
bind("Shell", "ALT + Tab", hl.dsp.global("quickshell:switcherNext"), "Window switcher (next)")
bind("Shell", "ALT + SHIFT + Tab", hl.dsp.global("quickshell:switcherPrev"), "Window switcher (previous)")
-- Release Alt to commit, the way a real switcher behaves.
bind("Shell", "ALT + Alt_L", hl.dsp.global("quickshell:switcherCommit"), "Release Alt to pick the switcher window",
    { release = true, transparent = true })
