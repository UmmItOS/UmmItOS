#!/usr/bin/env bash

# This script detects the system's distribution name and formats it for display.
# The formatted distribution name is then used in the Hyprlock configuration
# to display the distro name on the lock screen.

# Get the distribution name
distro=$(grep '^NAME=' /etc/os-release | cut -d '=' -f2 | tr -d '"' | awk '{print $1}')
print_result=$(awk '{print "🐧 " toupper(substr($0, 1, 1)) tolower(substr($0, 2))" btw 🐧"}' <<< "$distro")

# Check if distro is found
if [[ -n "$distro" ]]; then
    echo "$print_result"
else
    echo "Distro not found"
fi
