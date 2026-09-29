-- Permission changes need a Hyprland restart; they are not applied on reload.
hl.config({ ecosystem = { enforce_permissions = true } })

local function allow(binary)
    hl.permission({ binary = binary, type = "screencopy", mode = "allow" })
end

allow("/usr/bin/wl-screenrec")
allow("/usr/bin/grim")
allow(os.getenv("HOME") .. "/scripts/.*")
allow("/usr/bin/hyprpicker")
allow("/usr/bin/wommer")
