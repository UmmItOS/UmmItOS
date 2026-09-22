#!/usr/bin/env bash
# Battery readout for hyprlock (cmd[update:1000] in hyprlock.conf).
# Prints one line per battery, nothing on a desktop.

for battery_dir in /sys/class/power_supply/BAT*; do
    [[ -d "$battery_dir" ]] || continue
    battery_status=$(cat "$battery_dir/status")
    battery_capacity=$(cat "$battery_dir/capacity")

    case $battery_status in
        Charging) echo "⚡ $battery_capacity% charging" ;;
        Full) echo "🔋 $battery_capacity% full" ;;
        Discharging)
            if (( battery_capacity > 50 )); then
                echo "🔋 $battery_capacity%"
            elif (( battery_capacity > 25 )); then
                echo "🪫 $battery_capacity%"
            elif (( battery_capacity > 15 )); then
                echo "🪫 $battery_capacity% low"
            else
                echo "🚨 $battery_capacity% critical"
            fi
            ;;
        *) echo "🔋 $battery_capacity%" ;;
    esac
done
