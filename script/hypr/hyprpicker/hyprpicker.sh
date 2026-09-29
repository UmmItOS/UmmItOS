#!/usr/bin/env bash

# Define a function to send notifications and log them
notify() {
    local message="$1"
    local urgency="$2"

    # Send the notification through the shell's notification server
    notify-send -a "Color picker" -u "$urgency" "Color picker" "$message"

    # Get the current date and time in the specified format
    local datetime
    datetime=$(date +"%Y-%m-%d %H:%M:%S")
    local noti="NOTICE"
    local message_show="It's Hyprpicker"

    # Log the notification message to a .log file
    echo "<$noti> $datetime: $message $message_show" >> ~/script/hypr/hyprpicker/hyprpicker.log
}


# Check if hyprpicker is installed
if ! command -v hyprpicker &> /dev/null; then
    notify "Hyprpicker is not installed." critical
    exit 1
fi

# Run hyprpicker and capture the output
color=$(hyprpicker --autocopy)

# Check if a color was selected
if [[ -z "$color" ]]; then
    # If no color was selected, notify the user
    notify "No color selected." low
else
    # Remove the '#' from the color
    color=${color/#\#/}

    # Notify the user that the color has been copied to the clipboard using the picked color
    notify "#$color copied to clipboard." normal

    # Just for the terminal display
    echo "$color"
fi
