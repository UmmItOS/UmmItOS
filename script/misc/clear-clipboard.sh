#!/usr/bin/env bash

# ----------------------------------------------------------
# Clipboard Cleaner Script
# Designed for use with wl-paste and cliphist
# This script prompts the user to clear the clipboard history.
# ----------------------------------------------------------

# shellcheck source=script/misc/_ui.sh
source "$(dirname "$0")/_ui.sh"

# Banner for clipboard Cleaner
ascii_art="\
╔═╗┬  ┬┌─┐┌┐ ┌─┐┌─┐┬─┐┌┬┐  ╔═╗┬  ┌─┐┌─┐┌┐┌┌─┐┬─┐  
║  │  │├─┘├┴┐│ │├─┤├┬┘ ││  ║  │  ├┤ ├─┤│││├┤ ├┬┘ 
╚═╝┴─┘┴┴  └─┘└─┘┴ ┴┴└──┴┘  ╚═╝┴─┘└─┘┴ ┴┘└┘└─┘┴└─ 
"

echo -e "${COLOR_LIGHT_BLUE}${ascii_art}${COLOR_RESET}"
echo -e "${COLOR_GREEN}This script will clear your clipboard history.\nWould you like to proceed?\n\nIf you want to proceed, please press y to continue.\nIf you want to cancel, please press n to exit.${COLOR_RESET}"
while true; do
    echo -e "${COLOR_LIGHT_BLUE}"
    read -rp "[ACTION] Would you like to proceed? (y/n): " choice
    echo -e "${COLOR_RESET}"
    
    case "$choice" in
        y)
            cliphist wipe
            # The live clipboard is not in the history: without this the last copy still pastes.
            wl-copy --clear
            echo -e "[${COLOR_GREEN} SUCCESS ${COLOR_RESET}] Clipboard history has been cleared :)\n"
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
