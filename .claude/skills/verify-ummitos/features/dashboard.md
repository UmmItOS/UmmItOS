# Dashboard

The dashboard opens from the bar's clock, with tabs for the Dashboard view (media, weather, calendar) and System (gauges).

## Sub-features

- `dash-open`: `dashboard toggle` opens it on the last tab.
- `dash-tab`: `dashboard tab <n>` switches tabs (0 = Dashboard, then the following ones).
- `dash-close`: Escape or `dashboard close` closes it.

## How to get to it (user POV)

- Click the clock in the bar.
- Call `dashboard toggle` or `toggleTab <n>`.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- The dashboard is closed.

Steps:

- **Open.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh dashboard toggle`, then `.claude/skills/verify-ummitos/scripts/shot.sh dash-open`. The dashboard panel is visible below the bar.
- **Tab.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh dashboard tab 1`, then `.claude/skills/verify-ummitos/scripts/shot.sh dash-system`. The System tab with its gauges is shown.
- **Close.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh dashboard close`. `.claude/skills/verify-ummitos/scripts/run.sh hyprctl -j layers` no longer lists the dashboard layer.

## Gotchas

- With no MPRIS player on the private bus, the media panel shows its empty state.
- Weather needs network access to wttr.in, and the fake HOME has no saved place. The weather state may stay loading or empty, and that is not a failure of the dashboard.
