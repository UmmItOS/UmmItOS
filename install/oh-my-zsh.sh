#!/usr/bin/env bash
# shellcheck disable=SC1091

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Source library functions
source "$PARENT_DIR/lib/common.sh"
source "$PARENT_DIR/lib/display-utils.sh"

install_oh_my_zsh() {
    echo "${COLOR_BLUE}:: Checking for Oh My Zsh...${COLOR_RESET}"
    if ! command_exists zsh; then
        echo "${COLOR_DARK_RED}:: zsh is not installed.${COLOR_RESET}"
        echo "${COLOR_YELLOW}:: Install it by sudo pacman -S zsh or run the install.sh script again.${COLOR_RESET}"
        return 1
    fi

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        echo "${COLOR_BLUE}:: Installing Oh My Zsh...${COLOR_RESET}"
        if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
            echo "${COLOR_GREEN}:: Oh My Zsh installed successfully.${COLOR_RESET}"
        else
            echo "${COLOR_DARK_RED}:: Failed to install Oh My Zsh.${COLOR_RESET}"
            return 1
        fi
    else
        echo "${COLOR_GREEN}:: Oh My Zsh is already installed. Skipping.${COLOR_RESET}"
    fi

    # Install zsh-autosuggestions
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    if [[ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]]; then
        echo "${COLOR_BLUE}:: Installing zsh-autosuggestions...${COLOR_RESET}"
        git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
    else
        echo "${COLOR_GREEN}:: zsh-autosuggestions is already installed. Skipping.${COLOR_RESET}"
    fi
}

install_oh_my_zsh
