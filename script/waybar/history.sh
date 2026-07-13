#!/usr/bin/env bash

# ----------------------------------------------------------
# Clipboard Cleaner Script
# Designed for use with wl-paste and cliphist
# This script prompts the user to clear the clipboard history.
# ----------------------------------------------------------

# Function to check if wl-paste is running
is_wl_paste_running() {
    pgrep -x "wl-paste" > /dev/null 2>&1
}

# ANSI color codes
COLOR_LIGHT_BLUE='\e[94m'
COLOR_GREEN='\e[32m'
COLOR_DARK_RED='\e[31m'
COLOR_RESET='\e[0m'

# Banner for clipboard Cleaner
ascii_art="\
╔═╗┬  ┬┌─┐┌┐ ┌─┐┌─┐┬─┐┌┬┐  ╔═╗┬  ┌─┐┌─┐┌┐┌┌─┐┬─┐  
║  │  │├─┘├┴┐│ │├─┤├┬┘ ││  ║  │  ├┤ ├─┤│││├┤ ├┬┘ 
╚═╝┴─┘┴┴  └─┘└─┘┴ ┴┴└──┴┘  ╚═╝┴─┘└─┘┴ ┴┘└┘└─┘┴└─ 
"

if is_wl_paste_running; then
    echo -e "${COLOR_LIGHT_BLUE}${ascii_art}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}This script will clear your clipboard history.\nYou saw this message because wl-paste is currently running.\nWould you like to proceed?\n\nIf you want to proceed, please press y to continue.\nIf you want to cancel, please press n to exit.${COLOR_RESET}"
    while true; do
        echo -e "${COLOR_LIGHT_BLUE}"
        read -rp "[ACTION] Would you like to proceed? (y/n): " choice
        echo -e "${COLOR_RESET}"
        
        case "$choice" in
            y)
                cliphist wipe
                echo -e "[${COLOR_GREEN} SUCESS ${COLOR_RESET}] Clipboard history has been cleared :)\n"
                break
                ;;
            n)
              echo -e "[${COLOR_DARK_RED} CANCELLED ${COLOR_RESET}] Clipboard history has not been cleared :(\n"
                break
                ;;
            *)
                echo -e "[${COLOR_DARK_RED} ERROR ${COLOR_RESET}] Invalid input. Please try again :p\n"
                ;;
        esac
    done
else
    exit 1
fi
