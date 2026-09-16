#!/usr/bin/env bash
# shellcheck disable=SC1091

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Source library functions
source "$PARENT_DIR/lib/common.sh"
source "$PARENT_DIR/lib/display-utils.sh"

# Default config directory
config_dir="$HOME/.config"

# Function to safely copy configuration with existence check
safe_copy() {
    local src="$1"
    local dest="$2"
    local name="$3"
    local current="$4"
    local total="$5"
    
    echo "${COLOR_BLUE}[$current/$total] Processing $name configuration...${COLOR_RESET}"
    
    # Ensure the parent directory exists
    mkdir -p "$(dirname "$dest")"
    
    if [[ -d "$dest" ]] || [[ -f "$dest" ]]; then
        echo "${COLOR_YELLOW}:: $name already exists at $dest${COLOR_RESET}"
        if prompt_yna ":: Do you want to overwrite existing $name configuration?"; then
            echo "${COLOR_GREEN}:: [$current/$total] Overwriting $name configuration...${COLOR_RESET}"
            if [[ -d "$src" ]]; then
                mkdir -p "$dest"
                cp -rv "$src/." "$dest"
            else
                cp -rv "$src" "$dest"
            fi
            pause_and_continue
        else
            echo "${COLOR_YELLOW}:: [$current/$total] Skipping $name configuration copy.${COLOR_RESET}"
            pause_and_continue
        fi
    else
        echo "${COLOR_GREEN}:: [$current/$total] Copying $name configuration...${COLOR_RESET}"
        if [[ -d "$src" ]]; then
            mkdir -p "$dest"
            cp -rv "$src/." "$dest"
        else
            cp -rv "$src" "$dest"
        fi
    fi
}

# Record where this repo lives so script/misc/first-run.sh can find post-install.sh
record_repo_path() {
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ummitos"
    mkdir -p "$state_dir"
    echo "$PARENT_DIR" > "$state_dir/repo-path"
}

# Function to set zsh as default shell
set_zsh_default() {
    if [[ "$SHELL" == "/usr/bin/zsh" ]]; then
        echo "${COLOR_GREEN}:: We're detected that ZSH is already set as default shell!${COLOR_RESET}"
        return 0
    else
        echo "${COLOR_YELLOW}:: Setting zsh as default shell...${COLOR_RESET}"
        if chsh -s /usr/bin/zsh; then
            echo "${COLOR_GREEN}:: zsh set as default shell.${COLOR_RESET}"
            return 0
        else
            echo "${COLOR_DARK_RED}:: Failed to set zsh as default shell.${COLOR_RESET}"
            echo "${COLOR_YELLOW}:: You can manually set zsh as default shell later with: chsh -s /usr/bin/nu${COLOR_RESET}"
            return 1
        fi
    fi
}

# Function to copy all configuration files
copy_all_configs() {
    if prompt_yna ":: Copy configuration files?"; then
        safe_copy "$PARENT_DIR/configs/hypr" "$config_dir/hypr" "Hyprland" "1" "14"
        safe_copy "$PARENT_DIR/configs/kitty" "$config_dir/kitty" "Kitty" "2" "14"
        safe_copy "$PARENT_DIR/configs/fastfetch" "$config_dir/fastfetch" "Fastfetch" "3" "14"
        safe_copy "$PARENT_DIR/configs/waybar" "$config_dir/waybar" "Waybar" "4" "14"
        safe_copy "$PARENT_DIR/configs/rofi" "$config_dir/rofi" "Rofi" "5" "14"
        safe_copy "$PARENT_DIR/configs/swaync" "$config_dir/swaync" "SwayNC" "6" "14"
        safe_copy "$PARENT_DIR/configs/wlogout" "$config_dir/wlogout" "Wlogout" "7" "14"
        safe_copy "$PARENT_DIR/configs/mpv" "$config_dir/mpv" "MPV" "8" "14"
        safe_copy "$PARENT_DIR/configs/yazi" "$config_dir/yazi" "Yazi" "9" "14"
        safe_copy "$PARENT_DIR/configs/quickshell" "$config_dir/quickshell/ummitos" "Quickshell" "10" "14"

        safe_copy "$PARENT_DIR/script" "$HOME/script" "Scripts" "11" "14"
        record_repo_path
        safe_copy "$PARENT_DIR/.wallpaper" "$HOME/.wallpaper" "Wallpapers" "12" "14"
        
        echo "${COLOR_GREEN}:: Basic Configuration files copied successfully.${COLOR_RESET}"
        echo "${COLOR_GREEN}:: Now setting zsh as default shell...${COLOR_RESET}"

        set_zsh_default
        
        safe_copy "$PARENT_DIR/configs/.zshrc" "$HOME/.zshrc" "zsh" "13" "14"
        safe_copy "$PARENT_DIR/configs/starship.toml" "$config_dir/starship.toml" "Starship" "14" "14"

        echo "${COLOR_GREEN}:: All the files copied successfully.${COLOR_RESET}"
        pause_and_continue
    else
        echo "${COLOR_YELLOW}:: Skipping configuration file copying and updates.${COLOR_RESET}"
        echo "${COLOR_GREEN}:: You can copy the configuration files manually later.${COLOR_RESET}"
    fi
}

main() {
    display_config_banner

    copy_all_configs
}

main
