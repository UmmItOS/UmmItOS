#!/usr/bin/env bash

# Define colors
COLOR_YELLOW=$(tput setaf 3)
COLOR_GREEN=$(tput setaf 2)
COLOR_GREY=$(tput setaf 8)
COLOR_DARK_RED=$(tput setaf 1)
COLOR_RESET=$(tput sgr0)

# Function to check if a command is available
command_exists() {
    command -v "$1" &>/dev/null
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

# Repository configuration
repo_url='https://github.com/UmmItOS/UmmItOS.git'
repo='UmmItOS'

# Check if user wants to run the script
if prompt_yna "Do you want to run the script?"; then
    echo -e "${COLOR_GREEN}[+] Running setup script...${COLOR_RESET}"
else
    echo -e "${COLOR_GREY}[~] Exiting the program.${COLOR_RESET}"
    exit 0
fi

check_git
check_paru

# Check if user wants to clone the repository
if prompt_yna "Do you want to clone the repository?"; then
    echo -e "${COLOR_GREEN}[+] Cloning repository...${COLOR_RESET}"
    if git clone --depth 1 --shallow-submodules --recursive "$repo_url"; then
        echo -e "${COLOR_GREEN}[+] Repository cloned successfully.${COLOR_RESET}"
        cd "$repo" || exit 1
        if prompt_yna "Do you want to run the install script?"; then
            if [[ -f install.sh ]]; then
                echo -e "${COLOR_GREEN}[+] Running install script...${COLOR_RESET}"
                bash install.sh
            else
                echo -e "${COLOR_GREY}[~] No install script found.${COLOR_RESET}"
            fi
        else
            echo -e "${COLOR_GREY}[~] Install script not executed.${COLOR_RESET}"
        fi
    else
        echo -e "${COLOR_DARK_RED}[!] Cloning failed.${COLOR_RESET}"
    fi
else
    echo -e "${COLOR_GREY}[~] Repository not cloned.${COLOR_RESET}"
fi