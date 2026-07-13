#!/usr/bin/env bash

# This script is designed for scenarios where gaming with a KVM (Keyboard, Video, Mouse switch),
# activating hypridle, and using hyprlock to lock your screen may conflict with the KVM setup.
# This conflict can result in your KVM system shutting down unexpectedly, potentially causing
# data loss or system instability. Additionally, even if you are using KDE or GNOME, it's
# advisable to disable default idle options to prevent this issue, especially for GPU Passthrough users.
# Furthermore, the main system may become unresponsive, necessitating a system reboot.

# Define color variables
BLUE='\e[34m'
GREEN='\e[32m'
RESET='\e[0m'  # Reset color to default

# Function to check if hyprlock is running
check_hyprlock_running() {
    if pgrep -x "hyprlock" > /dev/null; then
        echo -e "${BLUE}:: Hyprlock is already running. No need to lock the system.${RESET}"
        return 0
    else
        return 1
    fi
}

# Function to check QEMU status
check_qemu_and_lock() {
    # Check if qemu-system-x86_64 is running
    if pgrep -x "qemu-system-x86_64" > /dev/null; then
        echo -e "${BLUE}:: QEMU is running.${RESET}"

        # Display notification about QEMU running
        notify-send "Hyprlock" \
                    "$(cat ~/script/hypr/hyprlock/message_hyprlock_qemu)" \
                    --app-name="hyprlock" \
                    --icon="hyprlock"
    else
        echo -e "${GREEN}:: QEMU is not running. Checking if hyprlock is running...${RESET}"

        # Check if hyprlock is running
        if check_hyprlock_running; then
            # Hyprlock is running, so do nothing
            return
        fi

        # Display notification that Hyprlock is about to lock after 15 seconds
        notify-send "Hyprlock" \
                    "$(cat ~/script/hypr/hyprlock/message_hyprlock)" \
                    --app-name="hyprlock" \
                    --icon="hyprlock"

        # Sleep 15 seconds and lock the system by hyprlock
        sleep 15

        # Execute hyprlock to lock the system
        hyprlock
    fi
}

# Check if QEMU is installed
if command -v qemu-system-x86_64 > /dev/null; then
    echo -e "${GREEN}:: QEMU is installed. Checking if qemu-system is launched or not...${RESET}"
    check_qemu_and_lock
else
    echo -e "${BLUE}:: QEMU is not installed. Checking if hyprlock is running...${RESET}"

    # Check if hyprlock is running
    if check_hyprlock_running; then
        # Hyprlock is running, so do nothing
        exit 0
    fi

    # Hyprlock is not running, so lock the system
    hyprlock
fi
