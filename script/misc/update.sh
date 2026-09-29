#!/usr/bin/env bash

# ANSI color codes
COLOR_LIGHT_BLUE='\e[94m'
COLOR_GREEN='\e[32m'
COLOR_DARK_RED='\e[31m'
COLOR_RESET='\e[0m'

# Function to print systemd-style status messages
print_status() {
    local status="$1"
    local message="$2"
    if [[ "${status}" == "SUCCESS" ]]; then
        echo -e "[ ${COLOR_GREEN}SUCCESS${COLOR_RESET} ] ${message}"
    else
        echo -e "[ ${COLOR_DARK_RED}FAILED${COLOR_RESET} ] ${message}"
    fi
}

# Function to execute commands and check for errors
execute_command() {
    local description="$1"
    shift
    if "$@"; then
        print_status "SUCCESS" "${description}"
        return 0
    else
        print_status "FAILED" "${description}"
        return 1
    fi
}

run_history() {
    # Execute history script first
    execute_command "Clipboard clean-up offered :)" bash "$HOME/script/misc/clear-clipboard.sh"
}

# Run history script
run_history


update_paru() {
    echo -e "[${COLOR_GREEN} RUNNING ${COLOR_RESET}] Full system upgrade via paru"
    execute_command "Processed full system upgrade via paru" paru
}

update_oh_my_zsh() {
    echo -e "[${COLOR_GREEN} RUNNING ${COLOR_RESET}] Upgrading oh my zsh"
    execute_command "Processed oh-my-zsh upgrade script" "$HOME/.oh-my-zsh/tools/upgrade.sh"
}

update_flatpak() {
    echo -e "[${COLOR_GREEN} RUNNING ${COLOR_RESET}] Upgrading Flatpak packages"
    execute_command "Processed Flatpak package upgrade" flatpak update
}

# Only what this system has is offered; anything missing is simply not mentioned.
labels=()
updaters=()
if command -v paru &> /dev/null; then
    labels+=("Full system upgrade via paru"); updaters+=(update_paru)
fi
if [[ -f "$HOME/.oh-my-zsh/tools/upgrade.sh" ]]; then
    labels+=("Upgrade oh-my-zsh"); updaters+=(update_oh_my_zsh)
fi
if command -v flatpak &> /dev/null; then
    labels+=("Upgrade Flatpak packages"); updaters+=(update_flatpak)
fi

# Run the selected update option, then report and log the duration
run_updates() {
    local start_time end_time total_duration updater
    start_time=$(date +%s)

    if [[ $update_choice == 0 ]]; then
        for updater in "${updaters[@]}"; do "$updater"; done
    else
        "${updaters[update_choice - 1]}"
    fi

    end_time=$(date +%s)
    total_duration=$((end_time - start_time))

    echo -e "[${COLOR_GREEN} SUCCESS ${COLOR_RESET}] System upgrade completed successfully.\nTotal duration: ${COLOR_GREEN}${total_duration}${COLOR_RESET} seconds"
    notify-send -a "Update" "System updated" "Finished in ${total_duration} seconds."
    echo "<NOTICE> $(date +"%Y-%m-%d %H:%M:%S"): System upgrade completed successfully. Total duration: ${total_duration} seconds" >> ~/script/misc/update.log
}

# Banner for upgrade system
echo -e "${COLOR_LIGHT_BLUE}"
cat << "EOF"
╦ ╦┌─┐┌─┐┬─┐┌─┐┌┬┐┌─┐  ╔═╗┬ ┬┌─┐┌┬┐┌─┐┌┬┐
║ ║├─┘│ ┬├┬┘├─┤ ││├┤   ╚═╗└┬┘└─┐ │ ├┤ │││
╚═╝┴  └─┘┴└─┴ ┴─┴┘└─┘  ╚═╝ ┴ └─┘ ┴ └─┘┴ ┴

EOF
echo -e "${COLOR_RESET}"

if (( ${#updaters[@]} == 0 )); then
    echo -e "Nothing on this system to update from here. Press any key to exit..."
    read -r
    exit 0
fi

# Display menu options
echo -e "${COLOR_GREEN}Please select an update option:${COLOR_RESET}"
echo -e "0 = Update ALL"
for i in "${!labels[@]}"; do
    echo -e "$((i + 1)) = ${labels[i]}"
done
echo -e "n/N/NO = Exit program"

# Get user's choice
while true; do
    echo -e "${COLOR_GREEN}"
    read -rp "Enter your choice (0-${#updaters[@]} or n/N/NO to exit): " update_choice
    echo -e "${COLOR_RESET}"

    case $update_choice in
        n|N|NO|no|No)
            echo -e "${COLOR_GREEN}Exiting program...${COLOR_RESET}"
            exit 0;;
    esac
    if [[ $update_choice =~ ^[0-9]+$ ]] && (( update_choice <= ${#updaters[@]} )); then
        break
    fi
    echo -e "${COLOR_DARK_RED}Invalid choice. Please enter a number between 0 and ${#updaters[@]}, or n/N/NO to exit.${COLOR_RESET}"
done

# Prompt user to confirm system upgrade
while true; do
    echo -e "${COLOR_GREEN}"
    read -rp "Do you want to proceed with the system upgrade? (y/n): " choice
    echo -e "${COLOR_RESET}"
    case $choice in
        [Yy]* )
            run_updates

            # Prompt user to reboot the system
            while true; do
                echo -e "${COLOR_GREEN}"
                read -rp "All operations have been completed. Would you like to reboot the system now? (y/n/r for reload): " reboot_choice
                echo -e "${COLOR_RESET}"
                case $reboot_choice in
                    [Yy]* )
                        notify-send -a "Update" -u critical "Rebooting" "The system will reboot in 5 seconds."
                        sleep 5
                        systemctl reboot
                        break;;
                    [Rr]* )
                        echo -e "${COLOR_GREEN}Reloading the selected update operation...${COLOR_RESET}"
                        run_updates
                        continue;;
                    [Nn]* )
                        break;;
                    * )
                        echo -e "${COLOR_DARK_RED}Please answer yes, no, or reload.${COLOR_RESET}";;
                esac
            done

            # Prompt user to press Enter to exit
            echo -e "Press any key to exit..."
            read -r
            break;;
        [Nn]* )
            echo -e "${COLOR_GREEN}System upgrade aborted. Press any key to exit...${COLOR_RESET}"
            read -r
            exit;;
        * )
            echo -e "${COLOR_DARK_RED}Please answer yes or no.${COLOR_RESET}";;
    esac
done
