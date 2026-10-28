# Dashboard

The dashboard opens below the bar and has three tabs:
- **Dashboard:** clock, month calendar and media.
- **System:** GPU temperature, CPU, memory and storage gauges.
- **Workspaces:** a grid of Hyprland workspaces.

## Sub-features

- `dash-open`: `dashboard toggle` opens it on the tab it last showed (0 in a fresh shell).
- `dash-tab`: `dashboard tab <n>` opens it on tab n (0 Dashboard, 1 System, 2 Workspaces).
- `dash-toggletab`: `dashboard toggleTab <n>` closes it when it is already open on tab n; otherwise it opens tab n.
- `dash-close`: `dashboard close`, or a click outside the panel, closes it.

## How to get to it (user POV)

- Click the clock in the bar: `toggleTab 0`.
- Click the bandwidth readout in the bar: `toggleTab 1`.
- IPC `dashboard toggle | tab <n> | close | toggleTab <n>`.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`. It includes "test shell reaches Hyprland IPC".
- The dashboard is closed.

Steps:

- **Open.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh dashboard toggle`, then `.claude/skills/verify-ummitos/scripts/shot.sh dash-open`. Expect the Dashboard tab: a big HH/mm clock, the month calendar and "Nothing playing". `.claude/skills/verify-ummitos/scripts/run.sh hyprctl -j layers` lists `ummitos-dashboard`.
- **Tabs.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh dashboard tab 1` and take a shot: four gauges. Run `.claude/skills/verify-ummitos/scripts/ipc.sh dashboard tab 2` and take a shot: the workspace grid, with one card per workspace that has an id above 0.
- **Toggle tab.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh dashboard toggleTab 2`. The layer is gone after about 1 s. Run `.claude/skills/verify-ummitos/scripts/ipc.sh dashboard toggle`: it reopens on Workspaces, because the tab is kept.
- **Close.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh dashboard close`. After about 1 s the layer list has no `ummitos-dashboard`.

## Gotchas

- Escape does **not** close the dashboard (proven 2026-10-29). Its keyboard focus is OnDemand and it has no Escape handler. Use `close` or a click outside the panel.
- The dashboard has no weather. Weather is on the bar's picker, the desktop card and the lock screen.
- The window stays mapped until its close animation ends. Wait about 1 s before checking that the layer is gone.
- The Workspaces tab and every other Hyprland-backed view need Hyprland IPC. If `doctor.sh` fails its socket2 check, the tab shows nothing. That is the harness failing, not the product.
