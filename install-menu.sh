#!/usr/bin/env bash
# shellcheck disable=SC1091

# Import library functions directly
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/display-utils.sh
source "$SCRIPT_DIR/lib/display-utils.sh"

# Package reading and installation are shared with install.sh
# shellcheck source=install/install-packages.sh
source "$SCRIPT_DIR/install/install-packages.sh"

# Simple menu function
simple_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0
    local total=${#options[@]}
    
    while true; do
        clear
        draw_header
        echo -e "${COLOR_YELLOW}${title}${COLOR_RESET}\n"
        
        # Display options
        for i in "${!options[@]}"; do
            if (( i == selected )); then
                echo -e "${COLOR_WHITE}► ${COLOR_YELLOW}${options[$i]}${COLOR_RESET}"
            else
                echo -e "  ${COLOR_GREEN}${options[$i]}${COLOR_RESET}"
            fi
        done
        
        echo -e "\n${COLOR_GREY}↑/↓ Navigate │ Enter Select │ b Back │ q Quit${COLOR_RESET}"
        
        # Read input
        read -rsn1 key
        case "$key" in
            $'\033') # Arrow keys
                read -rsn2 key
                case "$key" in
                    '[A') # Up
                        ((selected--))
                        (( selected < 0 )) && selected=$((total-1))
                        ;;
                    '[B') # Down
                        ((selected++))
                        (( selected >= total )) && selected=0
                        ;;
                esac
                ;;
            '') # Enter
                return $selected
                ;;
            'b'|'B') # Back
                return 254
                ;;
            'q'|'Q') # Quit
                return 255
                ;;
        esac
    done
}

# Installation steps; the install/ scripts print their own prompts and results
install_main_package() {
    clear
    display_banner_start
    install_main_packages
    enable_bluetooth
    pause_and_continue
}

install_gpu_package() {
    clear
    install_gpu_packages
    pause_and_continue
}

install_laptop_package() {
    clear
    if is_laptop; then
        display_laptop_banner
    fi
    install_laptop_packages
    pause_and_continue
}

copy_dotfiles() {
    clear
    bash ./install/copy-config.sh
}

enable_service() {
    clear
    if bash ./install/setup-dm.sh; then
        echo -e "${COLOR_GREEN}:: [5/5] Service enabled successfully!${COLOR_RESET}"
    else
        echo -e "${COLOR_DARK_RED}:: Service enabled failed. try run again?${COLOR_RESET}"
        pause_and_continue
        return 1
    fi
}

show_post_install_info() {
    clear
    draw_header

    echo -e "${COLOR_GREEN}Installation Complete!${COLOR_RESET}\n"
    echo -e "${COLOR_YELLOW}Post-installation notes:${COLOR_RESET}"
    echo -e "• Reboot your system to ensure all changes take effect"
    echo -e "• After reboot you can log in and start using the desktop"
    echo -e "• Your first login offers an optional tuning step for the monitor mode"
    echo -e "  and the screenshot folder. Run it later with:"
    echo -e "  ${COLOR_GREEN}./post-install.sh --start-config${COLOR_RESET}"
    if has_amdgpu; then
        echo -e "• Verify AMD GPU drivers are working properly"
    fi
    echo ""
    echo -e "${COLOR_BLUE}Enjoy your new system!${COLOR_RESET}\n"
    read -rp "Press Enter to exit..."
}

auto_install_all() {
    clear
    echo -e "\n${COLOR_DARK_RED}AUTOMATIC INSTALLATION MODE${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}This will install everything automatically...${COLOR_RESET}\n"
    
    local confirm_options=("Yes, proceed" "No, go back")
    simple_menu "Are you sure you want to auto-install everything?" "${confirm_options[@]}"
    local choice=$?
    
    if (( choice == 0 )); then
        echo -e "\n${COLOR_BLUE}Starting automatic installation...${COLOR_RESET}\n"
        
        echo -e "${COLOR_YELLOW}[1/5] Installing main packages...${COLOR_RESET}"
        pause_and_continue
        install_main_package
        
        echo -e "${COLOR_YELLOW}[2/5] Installing GPU packages...${COLOR_RESET}"
        pause_and_continue
        install_gpu_package
        
        echo -e "${COLOR_YELLOW}[3/5] Installing laptop packages...${COLOR_RESET}"
        pause_and_continue
        install_laptop_package
        
        echo -e "${COLOR_YELLOW}[4/5] Copying dotfiles...${COLOR_RESET}"
        pause_and_continue
        copy_dotfiles
        
        echo -e "${COLOR_YELLOW}[5/5] Enabling service...${COLOR_RESET}"
        pause_and_continue
        enable_service
        
        echo -e "\n${COLOR_GREEN}Automatic installation completed!${COLOR_RESET}"
        pause_and_continue
        show_post_install_info
        return 0
    else
        return 254  # Go back
    fi
}

# Package installation submenu
package_menu() {
    local package_options=("Main packages" "GPU packages" "Laptop packages" "Back to main menu")
    
    while true; do
        simple_menu "Package Installation:" "${package_options[@]}"
        local choice=$?
        
        case $choice in
            0) install_main_package ;;
            1) install_gpu_package ;;
            2) install_laptop_package ;;
            3|254) return ;; # Back to main menu
            255) exit 0 ;; # Quit
        esac
    done
}

# Main menu
main_menu() {
    local main_options=(
        "Install packages"
        "Copy dotfiles" 
        "Enable service"
        "Show post-install info"
        "Auto-install Process [1-5]"
        "Exit the installer"
    )
    
    while true; do
        simple_menu "If you are a new user, please select auto-install everything. \nOnly you know what you are doing if you choose to manually install process.)" "${main_options[@]}"
        local choice=$?
        
        case $choice in
            0) package_menu ;;
            1) copy_dotfiles ;;
            2) enable_service ;;
            3) show_post_install_info ;;
            4) auto_install_all && exit 0 ;;
            5|255) 
                clear
                echo -e "${COLOR_GREEN}Thanks for using the installer!${COLOR_RESET}"
                exit 0 
                ;;
        esac
    done
}

# Trap Ctrl+C
trap 'clear; echo -e "\n${COLOR_GREEN}Installation cancelled. Goodbye!${COLOR_RESET}"; exit 0' INT

# Welcome message
welcome() {
    clear
    draw_header
    echo -e "${COLOR_YELLOW}Welcome to the System Installation Script!${COLOR_RESET}\n"
    echo -e "This script will help you:"
    echo -e "• Install essential packages"
    echo -e "• Set up GPU drivers"
    echo -e "• Configure laptop optimizations"
    echo -e "• Copy your dotfiles"
    echo -e "• Enable display manager"
    echo -e "• Or do everything automatically!\n"
    echo -e "${COLOR_GREY}Press Enter to continue...${COLOR_RESET}"
    read -r
}

# Main execution
main() {

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo -e "${COLOR_DARK_RED}:: Running this script as root is not a good idea, just like running Hyprland as root. Are you unaware of this?${COLOR_RESET}"
        echo -e "${COLOR_DARK_RED}:: Please switch to normal user.${COLOR_RESET}"
        exit 1
    fi
    
    # Check if running on Arch Linux or Arch based distribution
    if [[ -f /etc/arch-release ]]; then
        welcome
        main_menu
    else
        echo -e "${COLOR_YELLOW}:: Hey, you need to become arch linux user to run this script xd${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}:: The script is only tested on arch linux environment.${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}:: Any arch based distribution is also supported. like EndeavourOS :D${COLOR_RESET}"
    fi
}

main "$@" 
