-- The shell's surfaces all use namespaces starting "ummitos-", so this one
-- rule blurs every one of them. The shell animates its own surfaces; a
-- compositor animation on top would double the entrance and leave a ghost
-- of the old frame on exit.
hl.layer_rule({
    name = "ummitos-shell",
    match = { namespace = "ummitos-.*" },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.1,
    no_anim = true,
})

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 20,
        border_size = 3,
        col = {
            -- A dark tone of the accent, not a light one: a bright top edge read as a
            -- white line under the bar.
            active_border = { colors = { "rgb(4a2a8a)", "rgb(2d1a55)", "rgb(24273A)", "rgb(3a2470)" }, angle = 45 },
            inactive_border = { colors = { "rgb(24273A)", "rgb(24273A)", "rgb(24273A)", "rgb(27273A)" }, angle = 45 },
        },
        layout = "master",
        resize_on_border = true,
        allow_tearing = true,
    },

    master = {
        new_status = "master",
        new_on_top = true,
        smart_resizing = true,
        slave_count_for_center_master = 1,
        allow_small_split = true,
    },

    decoration = {
        rounding = 20,
        blur = {
            enabled = true,
            size = 3,
            passes = 2,
            xray = true,
            brightness = 0.5,
            vibrancy = 0.1923,
            vibrancy_darkness = 0.9,
            special = true,
            popups = true,
            input_methods = true,
            input_methods_ignorealpha = 0.5,
        },
        inactive_opacity = 0.8,
        active_opacity = 1,
        fullscreen_opacity = 1.0,
    },
})
