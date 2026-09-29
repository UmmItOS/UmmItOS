-- Brightness, volume and media keys.

-- The description starts with the cheat sheet group it is listed under.
local function bind(keys, cmd, description, opts)
    opts = opts or {}
    opts.description = "Media: " .. description
    hl.bind(keys, hl.dsp.exec_cmd(cmd), opts)
end

-- Brightness. The OSD is told straight away rather than polling the backlight.
bind("XF86MonBrightnessUp", "brightnessctl set +1% && qs -c ummitos ipc call osd brightness", "Increase screen brightness")
bind("XF86MonBrightnessDown", "brightnessctl set 1%- && qs -c ummitos ipc call osd brightness", "Decrease screen brightness")

-- Volume, with wpctl from wireplumber
bind("XF86AudioRaiseVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+", "Increase volume", { repeating = true, locked = true })
bind("XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-", "Decrease volume", { repeating = true, locked = true })
bind("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "Toggle audio mute", { locked = true })

-- Media, with playerctl
bind("XF86AudioPlay", "playerctl play-pause", "Media play/pause", { locked = true })
bind("XF86AudioPrev", "playerctl previous", "Previous track", { locked = true })
bind("XF86AudioNext", "playerctl next", "Next track", { locked = true })
