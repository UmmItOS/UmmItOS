#!/usr/bin/env bash
# shellcheck disable=SC2153,SC1091

# Source common utilities if not already sourced
if [[ -z "$COLOR_GREEN" ]]; then
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=lib/common.sh
    source "$lib_dir/common.sh"
fi

# Function to display the banner for the main packages installation
display_banner_start() {
    cat <<EOF
${COLOR_GREY}---------------------------------------------------------${COLOR_RESET}
${COLOR_BLUE}Part 1: Installing Main Packages

This section will install the main packages listed in the packages_main file.
These packages are essential for ensuring that my dotfiles function properly.
The installation process will utilize paru to manage all package installations.
Please note that the installation of AUR packages may take some time, as they will be compiled from source.

The packages will be sourced from the official Arch Linux repositories, including:

- Extra repository
- Multilib repository
- AUR repository${COLOR_RESET}
${COLOR_GREY}---------------------------------------------------------${COLOR_RESET}
EOF
}

# Function to display the laptop banner
display_laptop_banner() {
    cat <<EOF
${COLOR_GREY}---------------------------------------------------------${COLOR_RESET}
${COLOR_BLUE}You saw this banner because you were detected as a laptop user.
This script will install brightnessctl and playerctl packages.
Which is useful for controlling screen brightness and media players.
and my dotfiles also use these tools.${COLOR_RESET}
${COLOR_GREY}---------------------------------------------------------${COLOR_RESET}
EOF
}

# Function to display the configuration copy banner
display_config_banner() {
    cat <<EOF
${COLOR_GREEN}--------------------------------------------------${COLOR_RESET}
${COLOR_BLUE}Part 2: Copying Configuration Files

This section will copy the configuration files to the appropriate directories.
Those configuration are preconfigured for my setup.
You should modify them according to your needs.
Such as the monitor configuration of hyprland.
This script is using cp -rv to copy the configuration files.
Please make sure to backup your existing configuration files before copying.

- hypr
- Nushell
- kitty
- fastfetch
- waybar
- rofi
- swaync
- wlogout
- mpv
- yazi
- script
- wallpaper${COLOR_RESET}

${COLOR_GREEN}--------------------------------------------------${COLOR_RESET}
EOF
}

display_manager_banner() {
    cat <<EOF
${COLOR_GREY}---------------------------------------------------------${COLOR_RESET}
${COLOR_BLUE}Part 3: Setting up Display Manager

This section will setup the display manager to be used.
The display manager is used to manage the display of the system.

Our display manager is using GDM.${COLOR_RESET}

${COLOR_GREY}---------------------------------------------------------${COLOR_RESET}
EOF
}

# Function to display completion message
display_completion_message() {
    echo "${COLOR_GREEN}:: Installation completed successfully.${COLOR_RESET}"
    echo "${COLOR_GREEN}:: Please reboot your system to apply all changes!${COLOR_RESET}"
    echo "${COLOR_GREEN}:: After reboot, run our settings script to finalize the setup of your system by executing: ${COLOR_RESET}"
    echo ""
    echo "${COLOR_GREEN}:: ./post-install.sh --start-config${COLOR_RESET}"
}

# Draw header
draw_header() {
    echo -e "${COLOR_BLUE}╔══════════════════════════════════════════════════════════════╗"
    echo -e "║                    UmmItOS Menu Installer :D                 ║"
    echo -e "╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}\n"
}

draw_header_cli() {
    echo -e "${COLOR_BLUE}╔══════════════════════════════════════════════════════════════╗"
    echo -e "║                    UmmItOS CLI Installer :D                  ║"
    echo -e "╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}\n"
}

# Function to show current monitor info
show_monitor_info() {
    echo "${COLOR_BLUE}Current monitor information:${COLOR_RESET}"
    echo ""
    if command_exists hyprctl; then
        hyprctl monitors
    else
        echo "${COLOR_YELLOW}   Hyprctl not available. Please run 'hyprctl monitors' after logging into Hyprland.${COLOR_RESET}"
    fi
}

# Function to show network interface info and populate interfaces array
show_network_info() {
    echo "${COLOR_BLUE}Available network interfaces:${COLOR_RESET}"
    # Store interfaces in a local array first, excluding 'lo' and handling potential errors
    local temp_interfaces
    mapfile -t temp_interfaces < <(ip -o link show | awk -F': ' '$2 != "lo" {print $2}' | cut -d'@' -f1)

    if (( ${#temp_interfaces[@]} == 0 )); then
        echo "${COLOR_DARK_RED}   No network interfaces found (excluding lo).${COLOR_RESET}"
        return 1
    fi

    # Copy to global interfaces array if it exists
    if declare -p interfaces &>/dev/null; then
        interfaces=("${temp_interfaces[@]}")
    fi

    for i in "${!temp_interfaces[@]}"; do
        printf "   ${COLOR_GREEN}%s) ${COLOR_CYAN}%s${COLOR_RESET}\n" "$((i+1))" "${temp_interfaces[i]}"
    done
    echo ""
    return 0
}

# Function to show current HYPRSHOT_DIR
show_hyprshot_info() {
    local env_file="$HOME/.config/hypr/hyprland/env.conf"
    echo "${COLOR_BLUE}Current HYPRSHOT_DIR setting from $env_file:${COLOR_RESET}"
    if [[ -f "$env_file" ]]; then
        grep "HYPRSHOT_DIR" "$env_file" || echo "${COLOR_YELLOW}   HYPRSHOT_DIR line not found in $env_file${COLOR_RESET}"
    else
        echo "${COLOR_YELLOW}   $env_file not found.${COLOR_RESET}"
    fi
    echo ""
}