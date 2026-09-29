-- Startup applications. The quickshell config in configs/quickshell is the
-- bar, notifications, wallpaper, launcher, session menu, OSD and lock screen.
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c ummitos")
    hl.exec_cmd("wl-paste --watch $HOME/script/cliphist/clip-store.sh")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("fcitx5")
    hl.exec_cmd('gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"')
    hl.exec_cmd("$HOME/script/misc/first-run.sh")
end)
