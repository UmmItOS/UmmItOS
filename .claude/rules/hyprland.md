---
paths:
  - "configs/hypr/**"
---

## Hyprland config is Lua

`configs/hypr/hyprland.lua` `require`s one module per concern from `configs/hypr/hyprland/`: `env`, `autostart`, `keybinds` (Hyprland's own), `shortcuts` (apps, shell, utilities), `media-keys`, `appearance`, `animations`, `input`, `misc`, `plugins`, `debug`, `permissions`. Hyprland 0.56 prefers `hyprland.lua` over `hyprland.conf` when both exist, and picks one only at startup, so a switch needs a new session. Check the API against `/usr/share/hypr/stubs/hl.meta.lua` (the installed version), not the wiki's `main`, which runs ahead of the release.

- **Check a change without restarting:** `Hyprland --verify-config -c configs/hypr/hyprland.lua` reports unknown keys and Lua errors. `hyprctl keyword` does not work under Lua; use `hyprctl eval '<lua>'` or `hyprctl dispatch '<hl.dsp… expression>'`.
- **Every bind has a `description` that starts with its cheat sheet group** (`Shell: Session menu`). Under Lua `hyprctl binds` reports every dispatcher as `__lua`, so the cheat sheet (`cheatsheet/`, Super+/) reads the group from that prefix. A bind without a description is missing from it.
- **Keys:** use key names (`Return`, not `code:36`, which loads as an empty key). 0.56.2 ignores `mouse = true` on `hl.bind`; `hl.dsp.window.drag()` and `resize()` handle the button themselves.
- **`~/.config/hypr` is a copy, not a symlink, and holds the user's own values** (monitor layout, `qt5ct`, portal autostarts, no permission rules; the repo's defaults otherwise match Kin's). Mirror a repo change into the matching live file by hand, back it up first, and never overwrite the live file with the repo's. Change the Hyprland config only when asked: a shell look is fixed in QML, not by changing global settings such as `decoration:blur`, which also affect every window.
- **End-to-end test:** run a nested `Hyprland -c <copy>.lua` from a copy that leaves out `require("hyprland.autostart")` (it would start a second `qs`), drive it with `hyprctl -i <instance> dispatch '…'`, then `hl.dsp.exit()`.
