#!/usr/bin/env bash

# shellcheck disable=SC2034
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
# shellcheck disable=SC2034
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

# Screen control
clear_screen() {
    clear
    printf '\033[2J\033[H'
}

# Draw header
draw_header() {
    echo -e "${MAGENTA}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           UmmItOS HOTKEY CHEATSHEET                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Draw footer
draw_footer() {
    echo -e "${GRAY}"
    echo "────────────────────────────────────────────────────────────────────────────────"
    echo -e "${YELLOW}Navigate: ${WHITE}↑/↓ or j/k${GRAY} │ ${YELLOW}Select: ${WHITE}Enter${GRAY} │ ${YELLOW}Back: ${WHITE}b or Backspace${GRAY} │ ${YELLOW}Quit: ${WHITE}q or Esc${NC}"
}

# Keybind categories and data
declare -A categories=(
    ["1"]="Window Management"
    ["2"]="Workspace Control"
    ["3"]="Applications & Launchers"
    ["4"]="Hardware Controls"
    ["5"]="System Actions"
    ["6"]="Screenshots & Media"
)

# Window Management keybinds
# shellcheck disable=SC2034
window_keybinds=(
    "SUPER + C|Close active window"
    "SUPER + V|Toggle window floating"
    "SUPER + J|Swap with next window"
    "SUPER + M|Exit Hyprland, known as Logout"
    "SUPRT + ←|Move to leftside current window"
    "SUPER + →|Move to rightside current window"
    "SUPER + ↑|Move to topside current window"
    "SUPER + ↓|Move to bottomside current window"
    "ALT + ←|Resize window left"
    "ALT + →|Resize window right"
    "ALT + ↑|Resize window up"
    "ALT + ↓|Resize window down"
)

# Workspace Control keybinds
# shellcheck disable=SC2034
workspace_keybinds=(
    "SUPER + <Number 1,2,3,4,5,6,7,8,9,0>| Switch to workspace 1-10"
    "SUPER + SHIFT + <Number 1,2,3,4,5,6,7,8,9,0>| Move active window to workspace 1-10"
    "SUPER + S|Toggle special workspace"
    "SUPER + SHIFT + S|Move to special workspace"
    "SUPER + Scroll|Switch workspaces"
)

# Applications & Launchers keybinds
# shellcheck disable=SC2034
apps_keybinds=(
    "SUPER + T|Launch terminal (kitty)"
    "SUPER + E|Launch file manager (yazi)"
    "SUPER + Enter|Application launcher"
    "SUPER + X|Power menu (wlogout)"
    "ALT + V|Clipboard manager"
    "ALT + W|Wallpaper picker"
    "ALT + E|Emoji picker (Smile)"
    "ALT + P|Color picker (Hyprpicker)"
    "ALT + O|Screen magnifier (woomer)"
    "ALT + R + Copilot Key (Laptop)|Ollama CLI"
    "SUPER + SHIFT + Enter|Upgrade UmmItOS"
)

# Hardware Controls keybinds
# shellcheck disable=SC2034
hardware_keybinds=(
    "Brightness Up|Increase screen brightness"
    "Brightness Down|Decrease screen brightness"
    "Volume Up|Increase volume"
    "Volume Down|Decrease volume"
    "Mute|Toggle audio mute"
    "Play/Pause|Media play/pause"
    "Previous Track|Previous media"
    "Next Track|Next media"
)

# System Actions keybinds
# shellcheck disable=SC2034
system_keybinds=(
    "SUPER + L|Lock screen"
    "SUPER + M|Exit Hyprland"
    "ALT + TAB|Window switcher"
)

# Screenshots & Media keybinds
# shellcheck disable=SC2034
media_keybinds=(
    "SUPER + Printsrc|Screenshot active window"
    "Printsrc|Screenshot full screen"
    "SHIFT + Printsrc|Screenshot region"
)

# Display keybind list
show_keybinds() {
    local category="$1"
    local -n keybinds_ref=$2
    local selected=0
    local total=${#keybinds_ref[@]}
    
    while true; do
        clear_screen
        draw_header
        echo -e "${CYAN}${BOLD}Category: ${category}${NC}\n"
        
        # Display keybinds
        for i in "${!keybinds_ref[@]}"; do
            local keybind="${keybinds_ref[$i]}"
            local key="${keybind%%|*}"
            local desc="${keybind##*|}"
            
            if (( i == selected )); then
                echo -e "${WHITE}${BOLD}► ${YELLOW}${key}${WHITE} - ${desc}${NC}"
            else
                echo -e "  ${GREEN}${key}${GRAY} - ${desc}${NC}"
            fi
        done

        echo ""
        draw_footer

        # Read user input
        read -rsn1 input
        case "$input" in
            $'\033')  # Escape sequence
                read -rsn2 -t 0.1 input
                case "$input" in
                    '[A'|'[k') # Up arrow
                        ((selected--))
                        (( selected < 0 )) && selected=$((total-1))
                        ;;
                    '[B'|'[j') # Down arrow
                        ((selected++))
                        (( selected >= total )) && selected=0
                        ;;
                esac
                ;;
            'j'|'J') # Down (vim style)
                ((selected++))
                (( selected >= total )) && selected=0
                ;;
            'k'|'K') # Up (vim style)
                ((selected--))
                (( selected < 0 )) && selected=$((total-1))
                ;;
            'q'|'Q'|$'\e') # Quit
                exit 0
                ;;
            'b'|'B'|$'\177') # Back (backspace)
                return
                ;;
            '') # Enter
                # Could add action :)
                ;;
        esac
    done
}

# Main menu
show_main_menu() {
    local selected=0
    local total=${#categories[@]}

    while true; do
        clear_screen
        draw_header
        echo -e "${CYAN}${BOLD}Select a category:${NC}\n"

        # Display categories
        local sorted_keys
        mapfile -t sorted_keys < <(printf '%s\n' "${!categories[@]}" | sort)
        for key in "${sorted_keys[@]}"; do
            local index=$((key-1))
            if (( index == selected )); then
                echo -e "${WHITE}${BOLD}► ${YELLOW}${key}. ${categories[$key]}${NC}"
            else
                echo -e "  ${GREEN}${key}. ${categories[$key]}${NC}"
            fi
        done

        draw_footer

        # Read user input
        read -rsn1 input
        case "$input" in
            $'\033')  # Escape sequence
                read -rsn2 -t 0.1 input
                case "$input" in
                    '[A'|'[k') # Up arrow
                        ((selected--))
                        (( selected < 0 )) && selected=$((total-1))
                        ;;
                    '[B'|'[j') # Down arrow
                        ((selected++))
                        (( selected >= total )) && selected=0
                        ;;
                esac
                ;;
            'j'|'J') # Down (vim style)
                ((selected++))
                (( selected >= total )) && selected=0
                ;;
            'k'|'K') # Up (vim style)
                ((selected--))
                (( selected < 0 )) && selected=$((total-1))
                ;;
            'q'|'Q'|$'\e') # Quit
                clear_screen
                echo -e "${GREEN}Thanks for using Hyprland Hotkey Cheatsheet!${NC}"
                exit 0
                ;;
            '') # Enter
                local cat_num=$((selected+1))
                case $cat_num in
                    1) show_keybinds "${categories[1]}" window_keybinds ;;
                    2) show_keybinds "${categories[2]}" workspace_keybinds ;;
                    3) show_keybinds "${categories[3]}" apps_keybinds ;;
                    4) show_keybinds "${categories[4]}" hardware_keybinds ;;
                    5) show_keybinds "${categories[5]}" system_keybinds ;;
                    6) show_keybinds "${categories[6]}" media_keybinds ;;
                esac
                ;;
            [1-6]) # Direct number selection
                case $input in
                    1) show_keybinds "${categories[1]}" window_keybinds ;;
                    2) show_keybinds "${categories[2]}" workspace_keybinds ;;
                    3) show_keybinds "${categories[3]}" apps_keybinds ;;
                    4) show_keybinds "${categories[4]}" hardware_keybinds ;;
                    5) show_keybinds "${categories[5]}" system_keybinds ;;
                    6) show_keybinds "${categories[6]}" media_keybinds ;;
                esac
                ;;
        esac
    done
}

# Cleanup handler for Ctrl+C
cleanup() {
    clear_screen
    echo -e "\n${GREEN}Thanks for using UmmITOS Hotkey Cheatsheet :)${NC}"
    exit 0
}

# Trap to handle Ctrl+C
trap cleanup INT

# Main execution
main() {

    # Check if running in terminal
    if [[ ! -t 1 ]]; then
        echo "This script must be run in a terminal."
        exit 1
    fi

    show_main_menu
}

main "$@"