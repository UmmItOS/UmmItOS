#!/usr/bin/env bash
# Upgrade UmmItOS: pick what to update in a colourful menu, watch each step
# run, then read how it went. Style: https://style.ysap.sh/

dir=${BASH_SOURCE[0]%/*}
[[ $dir == "${BASH_SOURCE[0]}" ]] && dir=.
# shellcheck source=script/misc/_ui.sh
source "$dir/_ui.sh"
# shellcheck source=script/misc/_tui.sh
source "$dir/_tui.sh"

log=$HOME/script/misc/update.log

banner=(
	'╦ ╦┌─┐┌─┐┬─┐┌─┐┌┬┐┌─┐  ╔═╗┬ ┬┌─┐┌┬┐┌─┐┌┬┐'
	'║ ║├─┘│ ┬├┬┘├─┤ ││├┤   ╚═╗└┬┘└─┐ │ ├┤ │││'
	'╚═╝┴  └─┘┴└─┴ ┴─┴┘└─┘  ╚═╝ ┴ └─┘ ┴ └─┘┴ ┴'
)
sel_title='What should be updated?'
sel_box=Updates
sel_hint='↑/↓ move · space tick · y auto-yes · a all/none · enter run'
results_ok='Everything is up to date'
choices=('Reboot now' 'Run again' 'Change the selection' 'Open a shell' 'Exit')
choice=4

yes=()
assume=0

update_repos() {
	local opts=()
	((assume)) && opts+=(--noconfirm)
	paru -Syu --repo "${opts[@]}"
}

update_aur() {
	local opts=()
	((assume)) && opts+=(--noconfirm)
	paru -Sua "${opts[@]}"
}

update_omz() { "$HOME/.oh-my-zsh/tools/upgrade.sh"; }

update_flatpak() {
	local opts=()
	((assume)) && opts+=(-y)
	flatpak update "${opts[@]}"
}

if command -v paru &> /dev/null; then
	labels+=('pacman')
	descs+=('Official repos only')
	steps+=(update_repos)
	labels+=('AUR')
	descs+=('AUR packages only')
	steps+=(update_aur)
fi
if [[ -f $HOME/.oh-my-zsh/tools/upgrade.sh ]]; then
	labels+=('oh-my-zsh')
	descs+=('Shell framework and plugins')
	steps+=(update_omz)
fi
if command -v flatpak &> /dev/null; then
	labels+=('flatpak')
	descs+=('Flatpak apps and runtimes')
	steps+=(update_flatpak)
fi
for i in "${!steps[@]}"; do
	picked[i]=1
	yes[i]=0
	tags[i]=
done

# y toggles auto-yes on the row; n leaves, like q.
update_key() {
	case $1 in
		y | Y)
			if [[ ${steps[cursor]} == update_omz ]]; then
				note='oh-my-zsh has nothing to confirm.'
			else
				((yes[cursor] = !yes[cursor]))
				tags[cursor]=
				((yes[cursor])) && tags[cursor]='auto-yes'
			fi
			;;
		n | N) exit 0 ;;
	esac
}
tui_key_hook=update_key

update_step() {
	assume=${yes[$1]}
}
tui_step_hook=update_step

run_steps() {
	local when
	tui_run
	tui_stamp when
	if ((failures)); then
		printf '<ERROR> %s: upgrade had %d failed step(s), %ds\n' \
			"$when" "$failures" "$total_secs" >> "$log"
		say Update 'Update did not finish' \
			"A step failed after $total_secs seconds." critical
	else
		printf '<NOTICE> %s: upgrade completed in %ds\n' \
			"$when" "$total_secs" >> "$log"
		say Update 'System updated' "Finished in $total_secs seconds."
	fi
	tui_wait
}

countdown_reboot() {
	local s
	say Update Rebooting 'The system will reboot in 5 seconds.' critical
	for s in 5 4 3 2 1; do
		tui_measure
		out=$'\e[H\e[2J\n\n'
		tui_emit "${fg_warn}${bold}Rebooting in $s..."
		tui_emit "${fg_mute}Press Ctrl+C to cancel."
		tui_flush
		sleep 1
	done
	tui_leave
	systemctl reboot
}

if [[ ! -t 0 || ! -t 1 ]]; then
	echo 'update.sh needs a terminal.' >&2
	exit 1
fi

tui_start

if ((${#steps[@]} == 0)); then
	tui_message 'Nothing on this system to update from here.'
	exit 0
fi

while true; do
	tui_enter
	tui_select || exit 0
	action=again
	while [[ $action == again ]]; do
		run_steps
		tui_results
		case $chosen in
			0) action=reboot ;;
			1) action=again ;;
			2) action=menu ;;
			3) action=shell ;;
			*) action='exit' ;;
		esac
	done
	case $action in
		reboot) countdown_reboot ;;
		shell)
			tui_leave
			exec "${SHELL:-/bin/bash}"
			;;
		exit) exit 0 ;;
	esac
done
