#!/usr/bin/env bash
# shellcheck disable=SC1091

# Import library functions directly
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/display-utils.sh
source "$SCRIPT_DIR/lib/display-utils.sh"

# Function to show wallpaper directory info
show_wallpaper_info() {
    local wallpaper_dir="$HOME/.wallpaper"
    echo "${COLOR_BLUE}Wallpaper directory status:${COLOR_RESET}"
    if [[ -d "$wallpaper_dir" ]]; then
        echo "${COLOR_GREEN}✓ Wallpaper directory exists${COLOR_RESET}"
        local count
        count=$(find "$wallpaper_dir" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) | wc -l)
        echo "Current wallpapers: $count files"
    else
        echo "${COLOR_YELLOW}Wallpaper directory will be created: $wallpaper_dir${COLOR_RESET}"
    fi
    echo ""
}

# Function to display usage information
display_usage() {
    local script_name="$1"
    echo "Usage: $script_name [command]"
    echo ""
    echo "A script to guide through post-installation configuration for UmmItOS and to display current setting :)"
    echo ""
    echo "Commands:"
    echo "  ${COLOR_GREEN}--start-config${COLOR_RESET}   Run the interactive post-installation configuration setup."
    echo "  ${COLOR_GREEN}--settings${COLOR_RESET}       Show current detected settings without making changes."
    echo "  ${COLOR_GREEN}--help${COLOR_RESET}           Show this help message."
}

# Function to read packages from a file into an array
read_packages_from_file() {
    local file_path="$1"
    local -n packages_array=$2
    
    packages_array=()
    
    if [[ ! -f "$file_path" ]]; then
        echo "${COLOR_DARK_RED}:: Package file not found: $file_path${COLOR_RESET}"
        return 1
    fi
    
    # Read packages from the file, skipping empty lines
    while IFS= read -r package; do
        # Check if the line is not empty
        if [[ -n "$package" ]]; then
            packages_array+=("$package")
        fi
    done < "$file_path"
    
    return 0
}

# Function to install packages with paru
install_packages_with_paru() {
    local -n packages=$1
    local package_type="$2"
    
    local total_packages=${#packages[@]}
    
    if (( total_packages == 0 )); then
        echo "${COLOR_YELLOW}:: No ${package_type} packages to install.${COLOR_RESET}"
        return 0
    fi
    
    if prompt_yna ":: Install these ${package_type} packages? - Total Package (${total_packages})"; then
        paru -S "${packages[@]}"
        
        pause_and_continue "${package_type} packages installed completed. Press any key to keep going :)"
        clear
    else
        echo "${COLOR_YELLOW}:: Skipping ${package_type} package installation.${COLOR_RESET}"
        
        pause_and_continue "${package_type} packages installation skipped. Press any key to keep going :)"
        clear
    fi
}

# Package file paths
PACKAGES_MAIN="$SCRIPT_DIR/install/packages_main"
PACKAGES_GPU="$SCRIPT_DIR/install/packages_gpu"
PACKAGES_LAPTOP="$SCRIPT_DIR/install/packages_laptop"

# Simple banner function for menu system compatibility
display_banner() {
    local message="$1"
    echo -e "${COLOR_GREY}---------------------------------------------------------${COLOR_RESET}"
    echo -e "${COLOR_BLUE}${message}${COLOR_RESET}"
    echo -e "${COLOR_GREY}---------------------------------------------------------${COLOR_RESET}"
}

# Simple menu function
simple_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0
    local total=${#options[@]}
    
    while true; do
        clear_screen
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
        
        echo -e "\n${COLOR_GRAY}↑/↓ Navigate │ Enter Select │ b Back │ q Quit${COLOR_RESET}"
        
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

# Real installation functions
install_main_package() {
    clear_screen
    display_banner_start
    
    local packages=()
    if ! read_packages_from_file "$PACKAGES_MAIN" packages; then
        read -rp "Press Enter to continue..."
        return 1
    fi
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        echo -e "${COLOR_RED}:: No packages found in $PACKAGES_MAIN${COLOR_RESET}"
        read -rp "Press Enter to continue..."
        return 1
    fi
    
    echo -e "${COLOR_GREEN}:: Main packages to be installed${COLOR_RESET}"
    local total_packages=${#packages[@]}
    printf "%s\n" "${packages[@]}" | column
    
    if prompt_yna ":: Install these packages? - Total Package (${total_packages})"; then
        install_packages_with_paru packages "main"
        read -rp ":: Main packages installation completed. Press any key to keep going :)"
        clear
    else
        echo -e "${COLOR_YELLOW}:: Skipping main package installation.${COLOR_RESET}"
        read -rp ":: Main packages installation skipped. Press any key to keep going :)"
        clear
    fi
}

install_gpu_package() {
    clear_screen
    
    # Check if AMD GPU is detected
    if has_amdgpu; then
        :
    else
        echo -e "${COLOR_YELLOW}:: AMD GPU not detected. Skipping GPU package installation.${COLOR_RESET}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    # Check if Nvidia GPU is detected
    if has_nvidiagpu; then
        echo -e "${COLOR_YELLOW}:: Nvidia GPU detected, but unfortunatly, this script is not support Nvidia GPU.${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}:: Since UmmItOS owner (UmmIt) is using AMD GPU, I dont even have Nvidia GPU to test for this script.${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}:: So, feel free to contribute to this script to support Nvidia GPU XD${COLOR_RESET}"
        read -rp "Press Enter to continue..."
        return 0
    else
        :
    fi
    
    local packages=()
    if ! read_packages_from_file "$PACKAGES_GPU" packages; then
        echo -e "${COLOR_RED}:: There's no packages can be read from $PACKAGES_GPU ????${COLOR_RESET}"
        echo -e "${COLOR_RED}:: Are you clone the repo correctly? Check the repo please!${COLOR_RESET}"
        read -rp "Press Enter to continue..."
        return 1
    fi
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        echo -e "${COLOR_RED}:: No packages found in $PACKAGES_GPU${COLOR_RESET}"
        read -rp "Press Enter to continue..."
        return 1
    fi
    
    echo -e "${COLOR_GREEN}:: GPU packages to be installed${COLOR_RESET}"
    local total_packages=${#packages[@]}
    printf "%s\n" "${packages[@]}" | column
    
    if prompt_yna ":: Install these GPU packages? - Total Package (${total_packages})"; then
        install_packages_with_paru packages "GPU"
        read -rp ":: GPU packages installation completed. Press any key to keep going :)"
        clear_screen
    else
        echo -e "${COLOR_YELLOW}:: Skipping GPU package installation.${COLOR_RESET}"
        read -rp ":: GPU packages installation skipped. Press any key to keep going :)"
        clear_screen
    fi
}

install_laptop_package() {
    clear_screen
    
    if is_laptop; then
        display_laptop_banner
    else
        echo -e "${COLOR_YELLOW}:: Laptop not detected, so the package is no need to install.${COLOR_RESET}"
        read -rp "Press Enter to continue..."
        clear_screen
        return 0
    fi
    
    display_laptop_banner
    
    local packages=()
    if ! read_packages_from_file "$PACKAGES_LAPTOP" packages; then
        read -rp "Press Enter to continue..."
        return 1
    fi
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        echo -e "${COLOR_RED}:: No packages found in $PACKAGES_LAPTOP${COLOR_RESET}"
        read -rp "Press Enter to continue..."
        return 1
    fi
    
    echo -e "${COLOR_GREEN}:: Laptop packages to be installed${COLOR_RESET}"
    local total_packages=${#packages[@]}
    printf "%s\n" "${packages[@]}" | column
    
    if prompt_yna ":: Install these laptop packages? - Total Package (${total_packages})"; then
        install_packages_with_paru packages "laptop"
        read -rp ":: Laptop packages installation completed. Press any key to keep going :)"
        clear
    else
        echo -e "${COLOR_YELLOW}:: Skipping laptop package installation.${COLOR_RESET}"
        read -rp ":: Laptop packages installation skipped. Press any key to keep going :)"
        clear
    fi
}

copy_dotfiles() {
    clear_screen
    echo -e "${COLOR_BLUE}:: Copying dotfiles...${COLOR_RESET}"

    # Check if the script exists
    if [[ -f "./install/copy-config.sh" ]]; then
        echo -e "${COLOR_GREEN}:: Running copy-config.sh script...${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}:: tesing now, not running anything now.${COLOR_RESET}"
        pause
        echo -e "${COLOR_GREEN}✓ Dotfiles, commands successfully!${COLOR_RESET}"
        echo -e "${COLOR_GREEN}:: [4/5] Dotfiles, commands successfully!${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}:: copy-config.sh not found, have you clone the repo correctly or you delete the script? Check the repo please.${COLOR_RESET}"
        read -rp "Press Enter to continue..."
    fi

    echo -e "${COLOR_GREEN}:: Copying dotfiles completed. Also sucessfully run the commands.${COLOR_RESET}"
}

enable_gdm_service() {
    clear_screen
    display_manager_banner

    # Check if gdm is installed
    if ! command_exists gdm; then
        echo -e "${COLOR_RED}:: gdm is not installed. turn back to main menu and install our main packages first.${COLOR_RESET}"
        read -rp "Press Enter to continue..."
        return 1
    fi
    
    if systemctl is-enabled gdm.service &> /dev/null; then
        echo -e "${COLOR_GREEN}:: gdm service is already enabled.${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}:: There's nothing to do here.${COLOR_RESET}"
        read -rp ":: Press Enter to continue..."
        return 0
    else
        echo -e "${COLOR_RED}:: gdm service is not enabled, now will enable it.${COLOR_RESET}"
        if prompt_yna ":: Enable gdm service?"; then
            if sudo systemctl enable gdm.service; then
                echo -e "${COLOR_GREEN}:: gdm service enabled successfully.${COLOR_RESET}"
                read -rp "Press Enter to continue..."
                return 0
            else
                echo -e "${COLOR_RED}:: Failed to enable gdm service.${COLOR_RESET}"
                read -rp "Press Enter to continue..."
                return 1
            fi
        else
            echo -e "${COLOR_YELLOW}:: You can enable it later by running 'sudo systemctl enable gdm.service'${COLOR_RESET}"
            read -rp "Press Enter to continue..."
            return 1
        fi
    fi
}

enable_service() {
    if enable_gdm_service; then
        echo -e "${COLOR_GREEN}:: [5/5] Service enabled successfully!${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}:: Service enabled failed. try run again?${COLOR_RESET}"
        read -rp "Press Enter to continue..."
        return 1
    fi
}

show_post_install_info() {
    clear_screen
    draw_header

    echo -e "${COLOR_GREEN}Installation Complete!${COLOR_RESET}\n"
    echo -e "${COLOR_YELLOW}Post-installation notes:${COLOR_RESET}"
    echo -e "• Reboot your system to ensure all changes take effect"
    echo -e "After reboot, run our settings script to finalize the setup of your system by executing: ${COLOR_GREEN}./post-install.sh --start-config${COLOR_RESET}"
    if has_amdgpu; then
        echo -e "• Verify AMD GPU drivers are working properly"
    fi
    echo ""
    echo -e "${COLOR_BLUE}Enjoy your new system!${COLOR_RESET}\n"
    read -rp "Press Enter to exit..."
}

auto_install_all() {
    clear_screen
    echo -e "\n${COLOR_RED}AUTOMATIC INSTALLATION MODE${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}This will install everything automatically...${COLOR_RESET}\n"
    
    local confirm_options=("Yes, proceed" "No, go back")
    simple_menu "Are you sure you want to auto-install everything?" "${confirm_options[@]}"
    local choice=$?
    
    if (( choice == 0 )); then
        echo -e "\n${COLOR_BLUE}Starting automatic installation...${COLOR_RESET}\n"
        
        echo -e "${COLOR_YELLOW}[1/5] Installing main packages...${COLOR_RESET}"
        pause
        install_main_package
        
        echo -e "${COLOR_YELLOW}[2/5] Installing GPU packages...${COLOR_RESET}"
        pause
        install_gpu_package
        
        echo -e "${COLOR_YELLOW}[3/5] Installing laptop packages...${COLOR_RESET}"
        pause
        install_laptop_package
        
        echo -e "${COLOR_YELLOW}[4/5] Copying dotfiles...${COLOR_RESET}"
        pause
        copy_dotfiles
        
        echo -e "${COLOR_YELLOW}[5/5] Enabling service...${COLOR_RESET}"
        pause
        enable_service
        
        echo -e "\n${COLOR_GREEN}Automatic installation completed!${COLOR_RESET}"
        pause
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
                clear_screen
                echo -e "${COLOR_GREEN}Thanks for using the installer! 👋${COLOR_RESET}"
                exit 0 
                ;;
        esac
    done
}

# Trap Ctrl+C
trap 'clear_screen; echo -e "\n${COLOR_GREEN}Installation cancelled. Goodbye! 👋${COLOR_RESET}"; exit 0' INT

# Welcome message
welcome() {
    clear_screen
    draw_header
    echo -e "${COLOR_YELLOW}Welcome to the System Installation Script!${COLOR_RESET}\n"
    echo -e "This script will help you:"
    echo -e "• Install essential packages"
    echo -e "• Set up GPU drivers"
    echo -e "• Configure laptop optimizations"
    echo -e "• Copy your dotfiles"
    echo -e "• Enable display manager"
    echo -e "• Or do everything automatically!\n"
    echo -e "${COLOR_GRAY}Press Enter to continue...${COLOR_RESET}"
    read -r
}

# Main execution
main() {

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo -e "${COLOR_RED}:: Running this script as root is not a good idea, just like running Hyprland as root. Are you unaware of this?${COLOR_RESET}"
        echo -e "${COLOR_RED}:: Please switch to normal user.${COLOR_RESET}"
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
