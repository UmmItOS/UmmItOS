#!/usr/bin/env bash
# shellcheck disable=SC1091

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library functions (only common utilities and display functions)
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/display-utils.sh"

# Function to display the post-installation banner
display_post_install_banner() {
    cat <<EOF
${COLOR_GREEN}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}
${COLOR_GREEN}║                    POST INSTALLATION GUIDE                   ║${COLOR_RESET}
${COLOR_GREEN}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}

${COLOR_YELLOW}This interactive guide will help you configure essential settings.${COLOR_RESET}
EOF
}

# Main interactive configuration function
run_interactive_configuration() {
    clear
    display_post_install_banner
    echo ""
    pause_and_continue "Press Enter to start with Configuration..."
    clear

    # Hyprland Main Configuration (Monitor line)
    print_header "Hyprland Main Configuration (hyprland.conf)"
    echo "${COLOR_YELLOW}This section will attempt to update the primary monitor configuration in your main Hyprland config.${COLOR_RESET}"
    local hyprland_conf_file_path="$HOME/.config/hypr/hyprland.conf"
    echo "${COLOR_GREY}   Configuration file: ${COLOR_GREEN}${hyprland_conf_file_path}${COLOR_RESET}"
    echo ""
    if [[  ! -f "$hyprland_conf_file_path"  ]]; then
        echo "${COLOR_DARK_RED}${hyprland_conf_file_path} not found. Skipping this step.${COLOR_RESET}"
    else
        if ! command_exists jq; then
            echo "${COLOR_DARK_RED}'jq' command not found. This is needed to accurately parse monitor details.${COLOR_RESET}"
            echo "${COLOR_YELLOW}Please install jq (e.g., 'sudo pacman -S jq') to use this feature.${COLOR_RESET}"
        else
            local current_monitor_line_val
            current_monitor_line_val=$(sed -n '3p' "$hyprland_conf_file_path")
            echo "${COLOR_BLUE}Current monitor line (line 3) in ${hyprland_conf_file_path}:${COLOR_RESET}"
            echo "${COLOR_GREY}   $current_monitor_line_val${COLOR_RESET}"
            echo ""
            
            # Get focused monitor details directly
            local new_monitor_line_val=""
            if command_exists hyprctl && command_exists jq; then
                local focused_monitor_json
                focused_monitor_json=$(hyprctl -j monitors | jq -c 'map(select(.focused == true)) | .[0]')

                if [[ -n "$focused_monitor_json" && "$focused_monitor_json" != "null" ]]; then
                    local name width height refresh_rate x y scale
                    name=$(echo "$focused_monitor_json" | jq -r '.name')
                    width=$(echo "$focused_monitor_json" | jq -r '.width')
                    height=$(echo "$focused_monitor_json" | jq -r '.height')
                    refresh_rate=$(echo "$focused_monitor_json" | jq -r '.refreshRate | tonumber | floor') # floor for integer Hz
                    x=$(echo "$focused_monitor_json" | jq -r '.x')
                    y=$(echo "$focused_monitor_json" | jq -r '.y')
                    scale=$(echo "$focused_monitor_json" | jq -r '.scale')

                    # Construct the monitor line. Defaulting scale to 1 if not explicitly different.
                    if [[ "$scale" == "1.00" || "$scale" == "1" ]]; then
                      scale_val="1"
                    else
                      scale_val="$scale"
                    fi

                    new_monitor_line_val="monitor=$name,${width}x${height}@${refresh_rate},${x}x${y},${scale_val}"
                fi
            fi
            
            if [[  -z "$new_monitor_line_val"  ]]; then
                echo "${COLOR_DARK_RED}Could not automatically determine new monitor configuration.${COLOR_RESET}"
                echo "${COLOR_YELLOW}Skipping automatic update for monitor line.${COLOR_RESET}"
            else
                echo "${COLOR_BLUE}Detected focused monitor configuration:${COLOR_RESET}"
                echo "   ${COLOR_CYAN}$new_monitor_line_val${COLOR_RESET}"
                echo ""
                if prompt_yna "Do you want to update line 3 of ${hyprland_conf_file_path} with this detected configuration?"; then
                    backup_file "$hyprland_conf_file_path"
                    sed -i "3s/.*/$new_monitor_line_val/" "$hyprland_conf_file_path"
                    local updated_line_val
                    updated_line_val=$(sed -n '3p' "$hyprland_conf_file_path")
                    if [[  "$updated_line_val" == "$new_monitor_line_val"  ]]; then
                        echo "${COLOR_GREEN}   Successfully updated monitor line in ${hyprland_conf_file_path}.${COLOR_RESET}"
                    else
                        echo "${COLOR_DARK_RED}   Failed to verify monitor line update. Current line 3 is:${COLOR_RESET}"
                        echo "      ${COLOR_GREY}$updated_line_val${COLOR_RESET}"
                        echo "${COLOR_YELLOW}      Please check manually. Original file backed up.${COLOR_RESET}"
                    fi
                else
                    echo "${COLOR_YELLOW}Monitor line update skipped by user.${COLOR_RESET}"
                fi
            fi
        fi
    fi
    echo ""

    # Hyprshot Configuration
    print_header "Hyprshot Configuration"
    echo "${COLOR_YELLOW}Hyprshot needs a directory to save screenshots.${COLOR_RESET}"
    pause_and_continue "Press Enter to continue to Hyprshot Configuration..."
    echo "${COLOR_GREY}This is configured in: ${COLOR_GREEN}~/.config/hypr/hyprland/env.conf${COLOR_RESET}"
    echo ""
    check_config_exists "$HOME/.config/hypr/hyprland/env.conf"
    show_hyprshot_info
    
    # Get current HYPRSHOT_DIR value directly
    local current_hyprshot_dir_val=""
    local env_file="$HOME/.config/hypr/hyprland/env.conf"
    if [[  -f "$env_file"  ]]; then
        # Extracts the path from a line like "env = HYPRSHOT_DIR, /path/to/dir"
        current_hyprshot_dir_val=$(grep -E "^[[:space:]]*env[[:space:]]*=[[:space:]]*HYPRSHOT_DIR[[:space:]]*,.*" "$env_file" | sed -E 's/^[[:space:]]*env[[:space:]]*=[[:space:]]*HYPRSHOT_DIR[[:space:]]*,[[:space:]]*(.*)[[:space:]]*$/\1/' | head -n 1)
    fi
    
    local desired_hyprshot_dir
    if [[  -n "$current_hyprshot_dir_val"  ]]; then
        desired_hyprshot_dir=$(prompt_with_default "Enter the full absolute path for HYPRSHOT_DIR (or press Enter for current '${current_hyprshot_dir_val}'): " "$current_hyprshot_dir_val")
    else
        desired_hyprshot_dir=$(prompt_with_default "Enter the full absolute path for HYPRSHOT_DIR (e.g., /home/your_user/Pictures/Screenshots): " "$HOME/Pictures/Screenshots")
    fi
    if [[  -z "$desired_hyprshot_dir"  ]]; then
        echo "${COLOR_DARK_RED}No path entered for HYPRSHOT_DIR. Skipping modification.${COLOR_RESET}"
    else
        echo "${COLOR_GREEN}You chose HYPRSHOT_DIR as: ${COLOR_CYAN}$desired_hyprshot_dir${COLOR_RESET}"
        if [[  ! -d "$desired_hyprshot_dir"  ]]; then
            echo "${COLOR_YELLOW}Directory '${desired_hyprshot_dir}' does not exist. Attempting to create it...${COLOR_RESET}"
            if mkdir -p "$desired_hyprshot_dir"; then
                echo "${COLOR_GREEN}   Successfully created directory '${desired_hyprshot_dir}'.${COLOR_RESET}"
            else
                echo "${COLOR_DARK_RED}   Failed to create directory '${desired_hyprshot_dir}'. Please check permissions or create it manually.${COLOR_RESET}"
            fi
        else
            echo "${COLOR_GREEN}Directory '${desired_hyprshot_dir}' already exists.${COLOR_RESET}"
        fi
        
        local env_conf_file_path="$HOME/.config/hypr/hyprland/env.conf"
        if [[  -f "$env_conf_file_path"  ]]; then
            backup_file "$env_conf_file_path"
            sed -i -E "s|^([[:space:]]*env[[:space:]]*=[[:space:]]*HYPRSHOT_DIR[[:space:]]*,)[[:space:]]*.*$|\1 $desired_hyprshot_dir|" "$env_conf_file_path"
            local updated_hyprshot_dir_val
            updated_hyprshot_dir_val=$(grep -E "^[[:space:]]*env[[:space:]]*=[[:space:]]*HYPRSHOT_DIR[[:space:]]*,.*" "$env_conf_file_path" | sed -E 's/^[[:space:]]*env[[:space:]]*=[[:space:]]*HYPRSHOT_DIR[[:space:]]*,[[:space:]]*(.*)[[:space:]]*$/\1/' | head -n 1)
            if [[  "$updated_hyprshot_dir_val" == "$desired_hyprshot_dir"  ]]; then
                echo "${COLOR_GREEN}Successfully updated HYPRSHOT_DIR in ${env_conf_file_path} to '${desired_hyprshot_dir}'${COLOR_RESET}"
            else
                echo "${COLOR_DARK_RED}Failed to update HYPRSHOT_DIR in ${env_conf_file_path}. Current value: '${updated_hyprshot_dir_val}'. Please check manually.${COLOR_RESET}"
                echo "${COLOR_YELLOW}Original file backed up. You might need to restore it or edit manually.${COLOR_RESET}"
            fi
        else
            echo "${COLOR_DARK_RED}Environment configuration file not found at ${env_conf_file_path}. Cannot apply changes.${COLOR_RESET}"
        fi
    fi
    echo ""
    pause_and_continue "Press Enter to continue to Current Settings Summary..."
    clear

    # Show current settings summary
    show_current_settings
    
    pause_and_continue "Press Enter to finish..."
    clear
    print_header "Configuration Complete!"
    echo "${COLOR_GREEN}Post-installation configuration has been completed.${COLOR_RESET}"
    echo "${COLOR_YELLOW}Please restart your Hyprland session or reboot to ensure all changes take effect.${COLOR_RESET}"
}

# Function to display usage information
display_usage() {
    local script_name="$1"
    echo "Usage: $script_name [command]"
    echo ""
    echo "A script to guide through post-installation configuration for UmmIt OS and Dotfiles,"
    echo "and to display current setting :)"
    echo ""
    echo "Commands:"
    echo "  ${COLOR_GREEN}--start-config${COLOR_RESET}   Run the interactive post-installation configuration setup."
    echo "  ${COLOR_GREEN}--settings${COLOR_RESET}       Show current detected settings without making changes."
    echo "  ${COLOR_GREEN}--help${COLOR_RESET}           Show this help message."
    echo ""
    echo "If no command is provided, this help message will be shown."
}

# Function to show current settings without interaction
show_current_settings() {
    print_header "Current Detected Settings"

    echo "${COLOR_MAGENTA}Hyprland Main Monitor (hyprland.conf line 3):${COLOR_RESET}"
    local hyprland_conf_file="$HOME/.config/hypr/hyprland.conf"
    if [[  -f "$hyprland_conf_file"  ]]; then
        local current_monitor_line
        current_monitor_line=$(sed -n '3p' "$hyprland_conf_file")
        echo "   ${COLOR_CYAN}$current_monitor_line${COLOR_RESET}"
    else
        echo "   ${COLOR_DARK_RED}${hyprland_conf_file} not found.${COLOR_RESET}"
    fi
    echo ""
    
    echo "${COLOR_MAGENTA}Hyprshot Screenshot Directory (env.conf):${COLOR_RESET}"
    local current_hyprshot_dir=""
    local env_file="$HOME/.config/hypr/hyprland/env.conf"
    if [[  -f "$env_file"  ]]; then
        current_hyprshot_dir=$(grep -E "^[[:space:]]*env[[:space:]]*=[[:space:]]*HYPRSHOT_DIR[[:space:]]*,.*" "$env_file" | sed -E 's/^[[:space:]]*env[[:space:]]*=[[:space:]]*HYPRSHOT_DIR[[:space:]]*,[[:space:]]*(.*)[[:space:]]*$/\1/' | head -n 1)
    fi
    if [[  -n "$current_hyprshot_dir"  ]]; then
        echo "   ${COLOR_CYAN}$current_hyprshot_dir${COLOR_RESET}"
    else
        if [[  -f "$env_file"  ]]; then
             echo "   ${COLOR_YELLOW}HYPRSHOT_DIR line not found or value not extracted from $env_file.${COLOR_RESET}"
        else
             echo "   ${COLOR_DARK_RED}$env_file not found.${COLOR_RESET}"
        fi
    fi
    echo ""
}

# Script execution / Argument parsing
if [[  -z "$1"  ]]; then
    display_usage "$(basename "$0")"
    exit 0
fi

# Parse command line arguments
case "$1" in
    --start-config)
        run_interactive_configuration
        ;;
    --settings)
        show_current_settings
        ;;
    --help)
        display_usage "$(basename "$0")"
        ;;
    *)
        echo "${COLOR_DARK_RED}Error: Unknown option '$1'${COLOR_RESET}" >&2
        display_usage "$(basename "$0")"
        exit 1
        ;;
esac