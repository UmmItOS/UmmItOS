#!/usr/bin/env bash

# Define color codes
DARK_RED='\033[0;31m'    # Dark Red
LIGHT_BLUE='\033[1;34m'  # Light Blue
CYAN='\033[0;36m'        # Cyan
GREEN='\033[0;32m'       # Green
YELLOW='\033[1;33m'      # Yellow
NC='\033[0m'             # No Color

while true; do
    echo -e "${LIGHT_BLUE}For exiting the script,\nplease enter 6 instead of Ctrl+C${NC}\n"
    echo -e "${LIGHT_BLUE}Generally, its script is for someone who wants to developing the environment.${NC}\n"
    echo -e "${LIGHT_BLUE}A menu for easily restarting/starting these applications :)\n${NC}"
    echo -e "${CYAN}Select an option:${NC}"

    echo -e "${CYAN}$(printf '%.0s-' {1..40})${NC}"
    echo -e "${YELLOW}1) Restart/Start swaync${NC}"
    echo -e "${YELLOW}2) Restart/Start waybar${NC}"
    echo -e "${YELLOW}3) Restart/Start ALL${NC}"
    echo -e "${YELLOW}4) Kill waybar, swaync${NC}"
    echo -e "${YELLOW}5) Exit${NC}"
    echo -e "${CYAN}$(printf '%.0s-' {1..40})${NC}"

    read -rp "${DARK_RED}Enter your choice: ${NC}" choice

    case $choice in
        1)
            # shellcheck disable=SC1091
            source ./swaync-restart.sh
            ;;
        2)
            # shellcheck disable=SC1091
            source ./waybar-restart.sh
            ;;
        3)
            # shellcheck disable=SC1091
            source ./waybar-restart.sh && source ./swaync-restart.sh
            ;;
        4)
            # shellcheck disable=SC1091
            source ./kill.sh
            ;;
        5)
            echo -e "${GREEN}Exiting...${NC}"
            break
            ;;
        *)
            echo -e "${DARK_RED}Invalid choice, please try again.${NC}"
            ;;
    esac
done
