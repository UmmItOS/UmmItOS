#!/usr/bin/env bash

# Define colors (only if not already defined)
# shellcheck disable=SC2034
if [[ -z "$COLOR_YELLOW" ]]; then
    COLOR_YELLOW=$(tput setaf 3)
    COLOR_GREEN=$(tput setaf 2)
    COLOR_GREY=$(tput setaf 8)
    COLOR_DARK_RED=$(tput setaf 1)
    COLOR_BLUE=$(tput setaf 4)
    COLOR_CYAN=$(tput setaf 6)
    COLOR_MAGENTA=$(tput setaf 5)
    COLOR_RESET=$(tput sgr0)
fi

# Function to check if git is installed and offer to install it
check_git() {
    if ! command_exists git; then
        echo -e "${COLOR_YELLOW}:: git is not installed.${COLOR_RESET}"
        if prompt_yna ":: Would you like to install git?"; then
            echo -e "${COLOR_GREEN}:: Installing git...${COLOR_RESET}"
            if ! sudo pacman -S git --noconfirm; then
                echo -e "${COLOR_DARK_RED}:: Failed to install git.${COLOR_RESET}"
                exit 1
            fi
        else
            echo -e "${COLOR_GREY}:: Exiting...${COLOR_RESET}"
            exit 0
        fi
    fi
}

# Function to check if paru is installed and offer to install it
check_paru() {
    if ! command_exists paru; then
        echo -e "${COLOR_YELLOW}:: paru is not installed.${COLOR_RESET}"
        if prompt_yna ":: Would you like to install paru?"; then
            echo -e "${COLOR_GREEN}:: Installing paru...${COLOR_RESET}"
            if ! (
                git clone https://aur.archlinux.org/paru.git &&
                cd paru || exit 1
                makepkg -si
            ); then
                echo -e "${COLOR_DARK_RED}:: Failed to install paru.${COLOR_RESET}"
                exit 1
            fi
        else
            echo -e "${COLOR_DARK_RED}:: Exiting...${COLOR_RESET}"
            exit 0
        fi
    fi
}

# Function to prompt for Yes/No
prompt_yna() {
    local prompt_message="$1"
    local choice
    while true; do
        read -rp "${COLOR_GREEN}${prompt_message} (Y/N): ${COLOR_RESET}" choice
        case $choice in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "${COLOR_DARK_RED}:: Please answer Y or N.${COLOR_RESET}" ;;
        esac
    done
}

# Function to check if a command is available
command_exists() {
    command -v "$1" &>/dev/null
}

# Function to prompt for installation confirmation
prompt_installation() {
    if prompt_yna ":: Do you want to continue with the installation?"; then
        return 0
    else
        echo "${COLOR_YELLOW}:: Installation aborted.${COLOR_RESET}"
        exit 0
    fi
}

# Function to print section headers
print_header() {
    echo "${COLOR_CYAN}================================${COLOR_RESET}"
    echo "${COLOR_CYAN}$1${COLOR_RESET}"
    echo "${COLOR_CYAN}================================${COLOR_RESET}"
}

# Function to check if configuration files exist
check_config_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        echo "${COLOR_GREEN}   Configuration file exists${COLOR_RESET}"
        echo ""
    else
        echo "${COLOR_DARK_RED}   Configuration file not found${COLOR_RESET}"
        echo ""
    fi
}

# Function to prompt with a default value, allowing user to edit or accept
prompt_with_default() {
    local prompt_message="$1"
    local default_value="$2"
    local user_input
    local colored_prompt="${COLOR_GREEN}${prompt_message}${COLOR_RESET}"

    IFS= read -r -e -p "$colored_prompt" -i "$default_value" user_input
    
    echo "$user_input"
}

# Function to backup a file with timestamp
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup_name
        backup_name="${file}.bak.$(date +%Y%m%d-%H%M%S)"
        cp "$file" "$backup_name"
        echo "${COLOR_GREY}Backed up original file to ${backup_name}...${COLOR_RESET}"
        return 0
    else
        return 1
    fi
}

# Function to pause and wait for user input
pause_and_continue() {
    local message="${1:-Press any key to keep going :)}"
    read -rp ":: ${message}"
}

# Function to check if running on a laptop
is_laptop() {
    [[ -f /sys/class/power_supply/BAT0/capacity ]]
}

# Function to check if AMD GPU is present
has_amdgpu() {
    lsmod | grep -q '^amdgpu\s'
}

# Function to check if Nvidia GPU is present
has_nvidiagpu() {
    lsmod | grep -q '^nvidia\s'
}

# Function to enable the Bluetooth stack
# bluez only ships the unit; nothing starts it, and the shell's Bluetooth menu
# has no adapter to talk to until it runs.
# The shell is the notification server now. A leftover daemon (swaync from an
# older UmmItOS) gets D-Bus-activated whenever the shell reloads, takes the
# notification name, and toasts silently stop.
retire_old_notifier() {
    if command_exists swaync; then
        systemctl --user mask swaync.service &> /dev/null &&
            echo "${COLOR_GREEN}:: Disabled the old swaync notification daemon.${COLOR_RESET}"
    fi
}

enable_bluetooth() {
    if ! command_exists bluetoothctl; then
        return 0
    fi

    if systemctl is-enabled bluetooth.service &> /dev/null; then
        echo "${COLOR_GREEN}:: Bluetooth is already enabled.${COLOR_RESET}"
        return 0
    fi

    if prompt_yna ":: Enable Bluetooth at boot?"; then
        if sudo systemctl enable --now bluetooth.service; then
            echo "${COLOR_GREEN}:: Bluetooth enabled.${COLOR_RESET}"
        else
            echo "${COLOR_DARK_RED}:: Failed to enable Bluetooth.${COLOR_RESET}"
            echo "${COLOR_YELLOW}:: You can enable it later with 'sudo systemctl enable --now bluetooth'${COLOR_RESET}"
        fi
    else
        echo "${COLOR_YELLOW}:: Skipping Bluetooth. Enable it later with 'sudo systemctl enable --now bluetooth'${COLOR_RESET}"
    fi
}

# The shell's Wi-Fi menu talks to NetworkManager, so it must be the running network service.
enable_networkmanager() {
    if ! command_exists NetworkManager; then
        return 0
    fi

    if systemctl is-enabled NetworkManager.service &> /dev/null; then
        echo "${COLOR_GREEN}:: NetworkManager is already enabled.${COLOR_RESET}"
        return 0
    fi

    echo "${COLOR_YELLOW}:: The Wi-Fi menu needs NetworkManager. If you set up iwd or systemd-networkd, disable it first.${COLOR_RESET}"
    if prompt_yna ":: Enable NetworkManager at boot?"; then
        if sudo systemctl enable --now NetworkManager.service; then
            echo "${COLOR_GREEN}:: NetworkManager enabled.${COLOR_RESET}"
        else
            echo "${COLOR_DARK_RED}:: Failed to enable NetworkManager.${COLOR_RESET}"
            echo "${COLOR_YELLOW}:: You can enable it later with 'sudo systemctl enable --now NetworkManager'${COLOR_RESET}"
        fi
    else
        echo "${COLOR_YELLOW}:: Skipping NetworkManager. Enable it later with 'sudo systemctl enable --now NetworkManager'${COLOR_RESET}"
    fi
}

# The 32-bit graphics packages live in multilib, which a fresh Arch leaves off. Returns 1 if it stays off.
ensure_multilib() {
    if grep -q '^\[multilib\]$' /etc/pacman.conf; then
        return 0
    fi

    if ! prompt_yna ":: Enable the multilib repository (32-bit graphics for games and Steam)?"; then
        echo "${COLOR_YELLOW}:: Skipping the 32-bit graphics packages.${COLOR_RESET}"
        return 1
    fi

    local backup
    backup="/etc/pacman.conf.bak.$(date +%Y%m%d-%H%M%S)"
    sudo cp /etc/pacman.conf "$backup" && echo "${COLOR_GREY}Backed up /etc/pacman.conf to ${backup}${COLOR_RESET}"
    sudo sed -i '/^#\[multilib\]$/{N;s/^#\[multilib\]\n#Include/[multilib]\nInclude/}' /etc/pacman.conf

    if grep -q '^\[multilib\]$' /etc/pacman.conf && sudo pacman -Sy; then
        echo "${COLOR_GREEN}:: multilib enabled.${COLOR_RESET}"
        return 0
    fi
    echo "${COLOR_DARK_RED}:: Could not enable multilib; skipping the 32-bit graphics packages.${COLOR_RESET}"
    return 1
}
