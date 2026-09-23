local home = os.getenv("HOME")

-- Theme for XCursors, GTK
hl.env("GTK_THEME", "Orchis-Dark")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XCURSOR_SIZE", "24")

-- Backend for each application
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

-- XDG Environment
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Mozilla based (like firefox, librewolf) set to wayland
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Where screenshots are saved (read by the shell; the name predates it).
-- post-install.sh rewrites this line; keep it one line.
hl.env("HYPRSHOT_DIR", home .. "/Pictures/Screenshots")

-- Default editor, terminal
hl.env("EDITOR", "nvim")
hl.env("TERM", "xterm-kitty")
