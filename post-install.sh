#!/usr/bin/env bash
# shellcheck disable=SC1091
# Tune the desktop after the first login: tick what to change, answer each
# step's questions, then see how it went. Needs a Hyprland session and jq.
# Style: https://style.ysap.sh/

repo=$(cd "${BASH_SOURCE[0]%/*}" && pwd)

source "$repo/lib/common.sh"
source "$repo/lib/display-utils.sh"
source "$repo/script/misc/_tui.sh"

hypr_conf=$HOME/.config/hypr/hyprland.lua
env_conf=$HOME/.config/hypr/hyprland/env.lua

# The first hl.monitor line of hyprland.lua, which the monitor step rewrites.
monitor_line() {
	grep -m1 '^hl\.monitor(' "$1"
}

# The HYPRSHOT_DIR value from env.lua: the path itself when it is a quoted
# string, otherwise the Lua expression as written.
hyprshot_dir() {
	grep -m1 '^hl\.env("HYPRSHOT_DIR"' "$1" | sed -E 's/^hl\.env\("HYPRSHOT_DIR",[[:space:]]*(.*)\)[[:space:]]*$/\1/; s/^"(.*)"$/\1/'
}

# The monitor line for the screen Hyprland says is focused, or nothing.
detect_monitor_line() {
	local json name width height rate x y scale
	command_exists hyprctl || return
	json=$(hyprctl -j monitors | jq -c 'map(select(.focused == true)) | .[0]')
	[[ -n $json && $json != null ]] || return
	name=$(jq -r '.name' <<< "$json")
	width=$(jq -r '.width' <<< "$json")
	height=$(jq -r '.height' <<< "$json")
	rate=$(jq -r '.refreshRate | tonumber | floor' <<< "$json")
	x=$(jq -r '.x' <<< "$json")
	y=$(jq -r '.y' <<< "$json")
	scale=$(jq -r '.scale' <<< "$json")
	[[ $scale == 1.00 ]] && scale=1
	printf 'hl.monitor({ output = "%s", mode = "%sx%s@%s", position = "%sx%s", scale = %s })' \
		"$name" "$width" "$height" "$rate" "$x" "$y" "$scale"
}

# Step: lock the first monitor line to the focused screen. Returns 1 when it
# could not, 0 when it did or you said no.
tune_monitor() {
	local current new line_no updated
	print_header 'Monitor mode (hyprland.lua)'
	echo "${COLOR_GREY}   File: ${COLOR_GREEN}$hypr_conf${COLOR_RESET}"
	echo ''
	if [[ ! -f $hypr_conf ]]; then
		echo "${COLOR_DARK_RED}$hypr_conf not found.${COLOR_RESET}"
		return 1
	fi
	if ! command_exists jq; then
		echo "${COLOR_DARK_RED}jq is needed to read the monitor.${COLOR_RESET}"
		echo "${COLOR_YELLOW}Install it first, for example: paru -S jq${COLOR_RESET}"
		return 1
	fi
	current=$(monitor_line "$hypr_conf")
	echo "${COLOR_BLUE}Now:${COLOR_RESET}"
	echo "${COLOR_GREY}   $current${COLOR_RESET}"
	echo ''
	new=$(detect_monitor_line)
	if [[ -z $new ]]; then
		echo "${COLOR_DARK_RED}Could not read the focused monitor.${COLOR_RESET}"
		return 1
	fi
	echo "${COLOR_BLUE}Detected:${COLOR_RESET}"
	echo "   ${COLOR_CYAN}$new${COLOR_RESET}"
	echo ''
	if ! prompt_yna "Replace the first hl.monitor line with the detected one?"; then
		echo "${COLOR_YELLOW}Left as it was.${COLOR_RESET}"
		return 0
	fi
	backup_file "$hypr_conf"
	line_no=$(grep -n -m1 '^hl\.monitor(' "$hypr_conf" | cut -d: -f1)
	if [[ -n $line_no ]]; then
		MONITOR_LINE=$new awk -v n="$line_no" \
			'NR == n { print ENVIRON["MONITOR_LINE"]; next } { print }' \
			"$hypr_conf" > "$hypr_conf.tmp" && mv "$hypr_conf.tmp" "$hypr_conf"
	fi
	updated=$(monitor_line "$hypr_conf")
	if [[ $updated == "$new" ]]; then
		echo "${COLOR_GREEN}Updated.${COLOR_RESET}"
		return 0
	fi
	echo "${COLOR_DARK_RED}Could not confirm the change. The line now reads:${COLOR_RESET}"
	echo "   ${COLOR_GREY}$updated${COLOR_RESET}"
	echo "${COLOR_YELLOW}The original is backed up beside it.${COLOR_RESET}"
	return 1
}

# Step: the folder screenshots are saved to, in env.lua.
tune_shots() {
	local current wanted updated
	print_header 'Screenshot folder (env.lua)'
	echo "${COLOR_GREY}   File: ${COLOR_GREEN}$env_conf${COLOR_RESET}"
	echo ''
	if [[ ! -f $env_conf ]]; then
		echo "${COLOR_DARK_RED}$env_conf not found.${COLOR_RESET}"
		return 1
	fi
	current=$(hyprshot_dir "$env_conf")
	# A Lua expression such as home .. "/Pictures" is not a path to offer.
	[[ $current == *[\"\\]* || $current == *..* ]] && current=$HOME/Pictures
	wanted=$(prompt_with_default "Full path of the screenshot folder: " "${current:-$HOME/Pictures/Screenshots}")
	if [[ -z $wanted ]]; then
		echo "${COLOR_YELLOW}No path given; left as it was.${COLOR_RESET}"
		return 0
	fi
	if [[ $wanted == *[\"\\]* ]]; then
		echo "${COLOR_DARK_RED}A path with \" or \\ cannot go into env.lua.${COLOR_RESET}"
		return 1
	fi
	if [[ ! -d $wanted ]]; then
		if ! mkdir -p "$wanted"; then
			echo "${COLOR_DARK_RED}Could not create $wanted.${COLOR_RESET}"
			return 1
		fi
		echo "${COLOR_GREEN}Created $wanted.${COLOR_RESET}"
	fi
	backup_file "$env_conf"
	HYPRSHOT_LINE="hl.env(\"HYPRSHOT_DIR\", \"$wanted\")" awk \
		'/^hl\.env\("HYPRSHOT_DIR"/ { print ENVIRON["HYPRSHOT_LINE"]; next } { print }' \
		"$env_conf" > "$env_conf.tmp" && mv "$env_conf.tmp" "$env_conf"
	updated=$(hyprshot_dir "$env_conf")
	if [[ $updated == "$wanted" ]]; then
		echo "${COLOR_GREEN}Screenshots go to $wanted.${COLOR_RESET}"
		return 0
	fi
	echo "${COLOR_DARK_RED}Could not confirm the change; it reads '$updated'.${COLOR_RESET}"
	echo "${COLOR_YELLOW}The original is backed up beside it.${COLOR_RESET}"
	return 1
}

show_current_settings() {
	local value
	print_header 'Current settings'
	echo "${COLOR_MAGENTA}Monitor (hyprland.lua):${COLOR_RESET}"
	if [[ -f $hypr_conf ]]; then
		echo "   ${COLOR_CYAN}$(monitor_line "$hypr_conf")${COLOR_RESET}"
	else
		echo "   ${COLOR_DARK_RED}$hypr_conf not found.${COLOR_RESET}"
	fi
	echo ''
	echo "${COLOR_MAGENTA}Screenshot folder (env.lua):${COLOR_RESET}"
	if [[ -f $env_conf ]]; then
		value=$(hyprshot_dir "$env_conf")
		echo "   ${COLOR_CYAN}${value:-HYPRSHOT_DIR not found in $env_conf}${COLOR_RESET}"
	else
		echo "   ${COLOR_DARK_RED}$env_conf not found.${COLOR_RESET}"
	fi
	echo ''
}

display_usage() {
	echo "Usage: $1 [command]"
	echo ''
	echo 'Tunes UmmItOS after the first login and shows what is set.'
	echo ''
	echo 'Commands:'
	echo "  ${COLOR_GREEN}--start-config${COLOR_RESET}   Pick what to tune, step by step."
	echo "  ${COLOR_GREEN}--settings${COLOR_RESET}       Show the current settings, change nothing."
	echo "  ${COLOR_GREEN}--help${COLOR_RESET}           Show this help."
}

start_tuning() {
	if [[ ! -t 0 || ! -t 1 ]]; then
		echo 'post-install.sh needs a terminal.' >&2
		exit 1
	fi
	banner=(
		'╦ ╦╔╦╗╔╦╗╦╔╦╗╔═╗╔═╗'
		'║ ║║║║║║║║ ║ ║ ║╚═╗'
		'╚═╝╩ ╩╩ ╩╩ ╩ ╚═╝╚═╝'
	)
	labels=('Monitor mode' 'Screenshot folder')
	descs=('Match hyprland.lua to this screen' 'Where screenshots are saved')
	steps=(tune_monitor tune_shots)
	picked=(1 1)
	tags=('' '')
	sel_title='What should be tuned?'
	sel_box=Tuning
	sel_hint='↑/↓ move · space tick · a all/none · enter go · q quit'
	results_ok='Tuned. Restart Hyprland or reboot to apply it'
	results_bad='%d step(s) did not finish'
	choices=('Show the current settings' 'Change the selection' 'Exit')
	choice=2
	tui_start
	while true; do
		tui_enter
		tui_select || exit 0
		tui_run
		tui_wait
		tui_results
		case $chosen in
			0)
				tui_leave
				clear
				show_current_settings
				tui_wait
				;;
			1) ;;
			*) exit 0 ;;
		esac
	done
}

case $1 in
	--start-config) start_tuning ;;
	--settings) show_current_settings ;;
	'' | --help) display_usage "${0##*/}" ;;
	*)
		echo "${COLOR_DARK_RED}Unknown option '$1'${COLOR_RESET}" >&2
		display_usage "${0##*/}"
		exit 1
		;;
esac
