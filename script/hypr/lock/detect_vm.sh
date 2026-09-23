#!/usr/bin/env bash

# This script is designed for scenarios where gaming with a KVM (Keyboard, Video, Mouse switch),
# activating hypridle, and locking the screen may conflict with the KVM setup.
# This conflict can result in your KVM system shutting down unexpectedly, potentially causing
# data loss or system instability. Additionally, even if you are using KDE or GNOME, it's
# advisable to disable default idle options to prevent this issue, especially for GPU Passthrough users.
# Furthermore, the main system may become unresponsive, necessitating a system reboot.

# Define color variables
BLUE='\e[34m'
GREEN='\e[32m'
RESET='\e[0m'  # Reset color to default

# The lock screen is the Quickshell shell; ask it rather than looking for a process.
check_locked() {
    if [[ "$(qs -c ummitos ipc call lock isLocked 2>/dev/null)" == "true" ]]; then
        echo -e "${BLUE}:: The screen is already locked.${RESET}"
        return 0
    else
        return 1
    fi
}

lock_screen() {
    qs -c ummitos ipc call lock lock
}

# Function to check QEMU status
check_qemu_and_lock() {
    # Check if qemu-system-x86_64 is running
    if pgrep -x "qemu-system-x86_64" > /dev/null; then
        echo -e "${BLUE}:: QEMU is running.${RESET}"

        # Display notification about QEMU running
        notify-send "Lock" \
                    "$(cat ~/script/hypr/lock/message_lock_qemu)" \
                    --app-name="Lock"
    else
        echo -e "${GREEN}:: QEMU is not running. Checking if the screen is already locked...${RESET}"

        # Check if the screen is already locked
        if check_locked; then
            # Already locked, so do nothing
            return
        fi

        # Warn that the screen will lock in 15 seconds
        notify-send "Lock" \
                    "$(cat ~/script/hypr/lock/message_lock)" \
                    --app-name="Lock"

        # Give 15 seconds to move the mouse, then lock
        sleep 15
        lock_screen
    fi
}

# Check if QEMU is installed
if command -v qemu-system-x86_64 > /dev/null; then
    echo -e "${GREEN}:: QEMU is installed. Checking if qemu-system is launched or not...${RESET}"
    check_qemu_and_lock
else
    echo -e "${BLUE}:: QEMU is not installed. Checking if the screen is already locked...${RESET}"

    # Check if the screen is already locked
    if check_locked; then
        # Already locked, so do nothing
        exit 0
    fi

    # Not locked yet, so lock
    lock_screen
fi
