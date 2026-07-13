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

    # Hyprlock Configuration
    print_header "🔒 Hyprlock Configuration"
    echo "${COLOR_YELLOW}Hyprlock needs to know which monitor to display on.${COLOR_RESET}"
    echo "${COLOR_GREY}The configuration file is: ${COLOR_GREEN}~/.config/hypr/hyprlock.conf${COLOR_RESET}"
    echo "${COLOR_GREY}You can list your monitor names by running: ${COLOR_GREEN}hyprctl monitors${COLOR_RESET}"
    echo ""

    check_config_exists "$HOME/.config/hypr/hyprlock.conf" # Check if file exists first

    # Get focused monitor name directly
    local default_monitor_name=""
    if command_exists hyprctl; then
        # Extracts the name like "DP-1" from the "Monitor DP-1 (ID 0):" line
        # for the monitor block that contains "focused: yes".
        default_monitor_name=$(hyprctl monitors | awk '/^Monitor / { M=$2 } /focused: yes/ { print M; exit }')
    fi

    local selected_monitor_name
    if [[  -n "$default_monitor_name"  ]]; then
        echo "${COLOR_BLUE}We detected '${default_monitor_name}' as a likely candidate (your currently focused monitor).${COLOR_RESET}"
        show_monitor_info
        selected_monitor_name=$(prompt_with_default "Enter monitor name for Hyprlock (or press Enter for default '${default_monitor_name}'): " "$default_monitor_name")
    else
        echo "${COLOR_YELLOW}Could not automatically detect a focused monitor (are you in a Hyprland session?).${COLOR_RESET}"
        echo "${COLOR_YELLOW}Please identify your monitor name from the list below or by running 'hyprctl monitors'.${COLOR_RESET}"
        show_monitor_info 
        selected_monitor_name=$(prompt_with_default "Enter monitor name for Hyprlock (e.g., DP-1): " "")
    fi

    if [[  -n "$selected_monitor_name"  ]]; then
        echo ""
        echo "${COLOR_GREEN}You entered: ${COLOR_CYAN}$selected_monitor_name${COLOR_RESET}"
        echo "${COLOR_YELLOW}Attempting to update ${COLOR_GREEN}~/.config/hypr/hyprlock.conf${COLOR_YELLOW} with monitor '${COLOR_CYAN}$selected_monitor_name${COLOR_CYAN}'...${COLOR_RESET}"
        
        local hyprlock_conf_file_path="$HOME/.config/hypr/hyprlock.conf"
        if [[  -f "$hyprlock_conf_file_path"  ]]; then
            backup_file "$hyprlock_conf_file_path"
            sed -i -E "s/^[[:space:]]*monitor[[:space:]]*=.*$/    monitor = $selected_monitor_name/" "$hyprlock_conf_file_path"
            if grep -q "^[[:space:]]*monitor[[:space:]]*= $selected_monitor_name" "$hyprlock_conf_file_path"; then
                echo "${COLOR_GREEN}✅ Successfully updated monitor settings in ${hyprlock_conf_file_path}${COLOR_RESET}"
            else
                echo "${COLOR_DARK_RED}❌ Failed to update monitor settings, or no monitor lines were found. Please check manually.${COLOR_RESET}"
                echo "${COLOR_YELLOW}Original file backed up. You might need to restore it or edit manually.${COLOR_RESET}"
            fi
        else
            echo "${COLOR_DARK_RED}❌ Hyprlock configuration file not found at ${hyprlock_conf_file_path}. Cannot apply changes.${COLOR_RESET}"
        fi
    else
        echo ""
        echo "${COLOR_DARK_RED}No monitor name entered. You will need to configure Hyprlock manually.${COLOR_RESET}"
        echo "${COLOR_YELLOW}Run ${COLOR_GREEN}hyprctl monitors${COLOR_YELLOW} to find your monitor name and edit ${COLOR_GREEN}~/.config/hypr/hyprlock.conf${COLOR_YELLOW}.${COLOR_RESET}"
    fi
    
    # Add a pause after Hyprlock section
    pause_and_continue "Press Enter to continue to Waybar Configuration..."
    clear
    
    # Waybar Configuration
    print_header "📊 Waybar Configuration"
    echo "${COLOR_YELLOW}Waybar needs to know which network interface to monitor.${COLOR_RESET}"
    echo "${COLOR_GREY}The configuration file is: ${COLOR_GREEN}~/.config/waybar/config.jsonc${COLOR_RESET}"
    echo ""
    check_config_exists "$HOME/.config/waybar/config.jsonc"
    declare -a interfaces
    if ! show_network_info; then
        echo "${COLOR_DARK_RED}Could not list network interfaces. Skipping Waybar network setup.${COLOR_RESET}"
    else
        # Prompt user to select interface directly
        local choice
        local num_interfaces=${#interfaces[@]}
        local selected_interface_name=""

        if (( num_interfaces == 0 )); then
            echo "${COLOR_DARK_RED}No network interfaces found.${COLOR_RESET}"
        else
            while true; do
                read -r -p "${COLOR_GREEN}Enter the number for the network interface you want to use (1-$num_interfaces): ${COLOR_RESET}" choice
                if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= num_interfaces )); then
                    selected_interface_name="${interfaces[$((choice-1))]}"
                    break
                else
                    echo "${COLOR_DARK_RED}Invalid selection. Please enter a number between 1 and $num_interfaces.${COLOR_RESET}"
                fi
            done
        fi

        if [[  -n "$selected_interface_name"  ]]; then
            echo ""
            echo "${COLOR_GREEN}You selected interface: ${COLOR_CYAN}$selected_interface_name${COLOR_RESET}"
            local waybar_conf_file_path="$HOME/.config/waybar/config.jsonc"
            if [[  -f "$waybar_conf_file_path"  ]]; then
                if ! command_exists jq; then
                    echo "${COLOR_DARK_RED}❌ 'jq' command not found. This script uses jq to modify JSON files.${COLOR_RESET}"
                    echo "${COLOR_YELLOW}Please install jq (e.g., 'sudo pacman -S jq') and run this section again${COLOR_RESET}"
                    echo "${COLOR_YELLOW}You need to set: ${COLOR_CYAN}\"interface\": \"$selected_interface_name\"${COLOR_YELLOW} in the network module.${COLOR_RESET}"
                else
                    backup_file "$waybar_conf_file_path"
                    jq --arg new_iface "$selected_interface_name" '.network.interface = $new_iface' "$waybar_conf_file_path" > "${waybar_conf_file_path}.tmp" && mv "${waybar_conf_file_path}.tmp" "$waybar_conf_file_path"
                    local current_waybar_iface
                    current_waybar_iface=$(jq -r '.network.interface' "$waybar_conf_file_path")
                    if [[  "$current_waybar_iface" == "$selected_interface_name"  ]]; then
                        echo "${COLOR_GREEN}✅ Successfully updated network interface in ${waybar_conf_file_path} to '${selected_interface_name}'${COLOR_RESET}"
                    else
                        echo "${COLOR_DARK_RED}❌ Failed to update network interface in ${waybar_conf_file_path}. Current value: '${current_waybar_iface}'. Please check manually.${COLOR_RESET}"
                        echo "${COLOR_YELLOW}Original file backed up. You might need to restore it or edit manually.${COLOR_RESET}"
                    fi
                fi
            else 
                echo "${COLOR_DARK_RED}❌ Waybar configuration file not found at ${waybar_conf_file_path}. Cannot apply changes.${COLOR_RESET}"
            fi
        else
            echo "${COLOR_DARK_RED}No network interface selected. You will need to configure Waybar manually.${COLOR_RESET}"
        fi
    fi
    echo ""
    # Add a pause after Waybar section
    pause_and_continue "Press Enter to continue to Hyprland Main Configuration..."
    clear

    # Hyprland Main Configuration (Monitor line)
    print_header "🖥️  Hyprland Main Configuration (hyprland.conf)"
    echo "${COLOR_YELLOW}This section will attempt to update the primary monitor configuration in your main Hyprland config.${COLOR_RESET}"
    local hyprland_conf_file_path="$HOME/.config/hypr/hyprland.conf"
    echo "${COLOR_GREY}   Configuration file: ${COLOR_GREEN}${hyprland_conf_file_path}${COLOR_RESET}"
    echo ""
    if [[  ! -f "$hyprland_conf_file_path"  ]]; then
        echo "${COLOR_DARK_RED}❌ ${hyprland_conf_file_path} not found. Skipping this step.${COLOR_RESET}"
    else
        if ! command_exists jq; then
            echo "${COLOR_DARK_RED}❌ 'jq' command not found. This is needed to accurately parse monitor details.${COLOR_RESET}"
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
                        echo "${COLOR_GREEN}   ✅ Successfully updated monitor line in ${hyprland_conf_file_path}.${COLOR_RESET}"
                    else
                        echo "${COLOR_DARK_RED}   ❌ Failed to verify monitor line update. Current line 3 is:${COLOR_RESET}"
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

    pause_and_continue "Press Enter to continue to User Path Adjustments for exec.conf..."
    clear

    # User Path Adjustments (exec.conf) - inline implementation
    local exec_conf_file="$HOME/.config/hypr/hyprland/exec.conf"
    local current_user_home_real="$HOME"
    # Ensure no trailing slash
    while [[ $current_user_home_real == */ ]]; do
        current_user_home_real=${current_user_home_real%/}
    done

    print_header "🔧 User Path Adjustments (exec.conf)"
    echo "${COLOR_YELLOW}This section will check for user-specific paths in your Hyprland exec config.${COLOR_RESET}"
    echo "${COLOR_GREY}Configuration file: ${COLOR_GREEN}${exec_conf_file}${COLOR_RESET}"
    echo "${COLOR_GREY}Current user home directory: ${COLOR_CYAN}${current_user_home_real}${COLOR_RESET}"
    echo ""

    if [[  ! -f "$exec_conf_file"  ]]; then
        echo "${COLOR_DARK_RED}   ❌ ${exec_conf_file} not found. Skipping this step.${COLOR_RESET}"
        pause_and_continue "Press Enter to continue..."
        clear
    else
        # Backup the file first
        backup_file "$exec_conf_file"
        echo ""
        pause_and_continue "Press Enter to review and confirm potential path changes in exec.conf..."

        local lines_to_check=(3 7)
        local overall_success=true
        local changes_made_or_needed=false
        local any_line_updated_successfully=false

        for line_num in "${lines_to_check[@]}"; do
            echo "${COLOR_BLUE}Processing line ${line_num}...${COLOR_RESET}"
            local original_line
            original_line=$(sed -n "${line_num}p" "$exec_conf_file")
            echo "   ${COLOR_GREY}Original: $original_line${COLOR_RESET}"

            # extract a /home/someuser path prefix from the line
            local existing_path_prefix
            existing_path_prefix=$(echo "$original_line" | grep -o -E '/home/[^/]+/' | head -n 1)
            # Remove trailing slash
            existing_path_prefix=${existing_path_prefix%/}

            if [[  -z "$existing_path_prefix"  ]]; then
                echo "   ${COLOR_YELLOW}No '/home/username/' path prefix found on this line. No changes needed.${COLOR_RESET}"
            elif [[  "$existing_path_prefix" == "$current_user_home_real"  ]]; then
                echo "   ${COLOR_GREEN}Path prefix '${existing_path_prefix}' matches current user home. No changes needed.${COLOR_RESET}"
            else
                # Path prefix exists and is different from current user's home
                changes_made_or_needed=true
                echo "   ${COLOR_YELLOW}Detected path prefix '${existing_path_prefix}' which differs from your home '${current_user_home_real}'.${COLOR_RESET}"
                
                local temp_sed_file="${exec_conf_file}.sedtmp"
                sed "${line_num}s#${existing_path_prefix}#${current_user_home_real}#g" "$exec_conf_file" > "$temp_sed_file"
                local proposed_line
                proposed_line=$(sed -n "${line_num}p" "$temp_sed_file")
                echo "   ${COLOR_CYAN}Proposed: $proposed_line${COLOR_RESET}"

                if prompt_yna "Apply this change to line ${line_num}?"; then
                    mv "$temp_sed_file" "$exec_conf_file"
                    any_line_updated_successfully=true
                    local updated_line
                    updated_line=$(sed -n "${line_num}p" "$exec_conf_file") 

                    # Verification: Check if the new home path is in, and the old detected one is out.
                    if [[ "$updated_line" == *"$current_user_home_real"* ]] && [[ "$updated_line" != *"$existing_path_prefix"* ]]; then
                        echo "${COLOR_GREEN}   ✅ Successfully updated line ${line_num}.${COLOR_RESET}"
                    else
                        echo "${COLOR_DARK_RED}   ❌ Failed to verify update on line ${line_num}. Please check manually.${COLOR_RESET}"
                        overall_success=false
                    fi
                else
                    echo "   ${COLOR_YELLOW}Change to line ${line_num} skipped by user.${COLOR_RESET}"
                    rm "$temp_sed_file"
                    overall_success=false
                fi
            fi
            echo ""
        done
        rm -f "${exec_conf_file}.sedtmp" # Clean up temp file if it exists

        if [[ "$any_line_updated_successfully" = true && "$overall_success" = true ]]; then
            echo "${COLOR_GREEN}All confirmed path changes in ${exec_conf_file} applied successfully.${COLOR_RESET}"
        elif [[ "$any_line_updated_successfully" = true ]]; then
            echo "${COLOR_YELLOW}Some path changes in ${exec_conf_file} were applied. Others were skipped or had issues. Please review.${COLOR_RESET}"
        elif [[ "$changes_made_or_needed" = true && "$overall_success" = false ]]; then
            echo "${COLOR_DARK_RED}Needed path changes in ${exec_conf_file} were skipped or failed. Manual check advised.${COLOR_RESET}"
        else
            echo "${COLOR_BLUE}No user-specific path changes were needed or made in ${exec_conf_file}.${COLOR_RESET}"
        fi
        pause_and_continue "Press Enter to continue..."
        clear
    fi

    # Hyprshot Configuration
    print_header "📸 Hyprshot Configuration"
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
                echo "${COLOR_GREEN}   ✅ Successfully created directory '${desired_hyprshot_dir}'.${COLOR_RESET}"
            else
                echo "${COLOR_DARK_RED}   ❌ Failed to create directory '${desired_hyprshot_dir}'. Please check permissions or create it manually.${COLOR_RESET}"
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
                echo "${COLOR_GREEN}✅ Successfully updated HYPRSHOT_DIR in ${env_conf_file_path} to '${desired_hyprshot_dir}'${COLOR_RESET}"
            else
                echo "${COLOR_DARK_RED}❌ Failed to update HYPRSHOT_DIR in ${env_conf_file_path}. Current value: '${updated_hyprshot_dir_val}'. Please check manually.${COLOR_RESET}"
                echo "${COLOR_YELLOW}Original file backed up. You might need to restore it or edit manually.${COLOR_RESET}"
            fi
        else
            echo "${COLOR_DARK_RED}❌ Environment configuration file not found at ${env_conf_file_path}. Cannot apply changes.${COLOR_RESET}"
        fi
    fi
    echo ""
    pause_and_continue "Press Enter to continue to Current Settings Summary..."
    clear

    # Show current settings summary
    show_current_settings
    
    pause_and_continue "Press Enter to finish..."
    clear
    print_header "✅ Configuration Complete!"
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
    print_header "🔍 Current Detected Settings"

    echo "${COLOR_MAGENTA}🔒 Hyprlock Monitor(s):${COLOR_RESET}"
    local hyprlock_conf_file="$HOME/.config/hypr/hyprlock.conf"
    if [[  -f "$hyprlock_conf_file"  ]]; then
        if grep -q -E "^[[:space:]]*monitor[[:space:]]*=" "$hyprlock_conf_file"; then
            grep -E "^[[:space:]]*monitor[[:space:]]*=" "$hyprlock_conf_file" | awk '!seen[$0]++' | sed 's/^/   /'
        else
            echo "   ${COLOR_YELLOW}No 'monitor =' lines found in $hyprlock_conf_file.${COLOR_RESET}"
        fi
    else
        echo "   ${COLOR_DARK_RED}${hyprlock_conf_file} not found.${COLOR_RESET}"
    fi
    echo ""

    echo "${COLOR_MAGENTA}📊 Waybar Network Interface:${COLOR_RESET}"
    local waybar_conf_file="$HOME/.config/waybar/config.jsonc"
    if [[  -f "$waybar_conf_file"  ]]; then
        if command_exists jq; then
            local current_iface
            current_iface=$(jq -r '.network.interface' "$waybar_conf_file" 2>/dev/null)
            if [[ -n "$current_iface" && "$current_iface" != "null" ]]; then
                echo "   ${COLOR_CYAN}$current_iface${COLOR_RESET}"
            else
                echo "   ${COLOR_YELLOW}Network interface not set or 'network' block/key not found in $waybar_conf_file.${COLOR_RESET}"
            fi
        else
            echo "   ${COLOR_YELLOW}'jq' not found. Cannot automatically read Waybar config.${COLOR_RESET}"
        fi
    else
        echo "   ${COLOR_DARK_RED}${waybar_conf_file} not found.${COLOR_RESET}"
    fi
    echo ""

    echo "${COLOR_MAGENTA}🖥️  Hyprland Main Monitor (hyprland.conf line 3):${COLOR_RESET}"
    local hyprland_conf_file="$HOME/.config/hypr/hyprland.conf"
    if [[  -f "$hyprland_conf_file"  ]]; then
        local current_monitor_line
        current_monitor_line=$(sed -n '3p' "$hyprland_conf_file")
        echo "   ${COLOR_CYAN}$current_monitor_line${COLOR_RESET}"
    else
        echo "   ${COLOR_DARK_RED}${hyprland_conf_file} not found.${COLOR_RESET}"
    fi
    echo ""
    
    echo "${COLOR_MAGENTA}📸 Hyprshot Screenshot Directory (env.conf):${COLOR_RESET}"
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

    echo "${COLOR_MAGENTA}🔧 User Paths in exec.conf (Lines 3 & 7):${COLOR_RESET}"
    local exec_conf_file="$HOME/.config/hypr/hyprland/exec.conf"
    if [[  -f "$exec_conf_file"  ]]; then
        local line3
        local line7
        line3=$(sed -n '3p' "$exec_conf_file")
        line7=$(sed -n '7p' "$exec_conf_file")
        echo "   Line 3: ${COLOR_CYAN}$line3${COLOR_RESET}"
        echo "   Line 7: ${COLOR_CYAN}$line7${COLOR_RESET}"
    else
        echo "   ${COLOR_DARK_RED}${exec_conf_file} not found.${COLOR_RESET}"
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
        # Check dependencies
        check_git
        check_paru
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