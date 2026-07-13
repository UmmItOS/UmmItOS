#!/usr/bin/env bash

# Define the directory where recordings will be saved
recording_dir="/home/$USER/Videos/wf-recorder"

# Function to handle recording start or stop
record_or_stop() {
    # Check if the recording directory exists; create it if not
    if [[ ! -d $recording_dir ]]; then
        mkdir -p "$recording_dir" || { echo "Error: Failed to create the directory $recording_dir"; exit 1; }
    fi

    # Check if recording should start or stop
    if [[ $SWAYNC_TOGGLE_STATE == true ]]; then
        # Start recording
        local filename
        filename="$recording_dir/wf-recorder-$(date +'%Y-%m-%d-%H-%M-%S').mp4"
        hyprctl notify 1 5000 "rgb(00FF00)" "fontsize:35   Video recording started with wf-recorder 📹"
        echo "<NOTICE> $(date +"%Y-%m-%d %H:%M:%S"): Video recording started with wf-recorder - $filename" >> ~/script/swaync/wf-recorder.log

        wf-recorder -a --file "$filename"
    else
        # Stop recording
        local pid
        pid=$(pidof wf-recorder)

        if [[ -n $pid ]]; then
            # Send SIGINT signal to stop wf-recorder
            echo "Sending Ctrl + C signal to wf-recorder with PID $pid"
            kill -SIGINT "$pid"

            # Get the most recent recording file
            local filename
            filename=$(find "$recording_dir" -maxdepth 1 -type f -printf '%T@ %p\n' | sort -rn | head -n1 | cut -d' ' -f2-)
            echo "Video recording ended and saved to $filename"
            hyprctl notify 5 5000 "rgb(00FF00)" "fontsize:35   Video recording ended and saved to: $recording_dir/$filename 📹"
            echo "<NOTICE> $(date +"%Y-%m-%d %H:%M:%S"): Video recording ended and saved to: $recording_dir/$filename - wf-recorder" >> ~/script/swaync/wf-recorder.log
        else
            echo "wf-recorder is not running."
            echo "<NOTICE> $(date +"%Y-%m-%d %H:%M:%S"): wf-recorder is not running - wf-recorder" >> ~/script/swaync/wf-recorder.log
        fi
    fi
}

# Call the function to start or stop recording
record_or_stop
