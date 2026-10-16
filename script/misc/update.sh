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
results_ok='✔ Update complete: every step finished successfully'
choices=('Reboot now' 'Run again' 'Change the selection' 'Open a shell' 'Exit')
choice=4

yes=()
assume=0
snapshot=

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

# Fills the results screen's Status box: how this run went, the run before
# it, what is still waiting to update, and whether a reboot is due.
update_status() {
	local when=$1 before=$2 list rc repo=0 aur=0 flat=0 left
	local checked=1 text up new gone
	results_info=()
	results_ok='✔ Update complete: every step finished successfully'
	printf '\n%sChecking what is left to update...%s\n' "$fg_mute" "$reset"
	if command -v checkupdates &> /dev/null; then
		list=$(checkupdates 2> /dev/null)
		rc=$?
		# 2 is "nothing to update"; anything else but 0 is a failed check.
		if ((rc == 0)); then
			repo=$(wc -l <<< "$list")
		elif ((rc != 2)); then
			checked=0
		fi
	fi
	if command -v paru &> /dev/null; then
		list=$(paru -Qua 2> /dev/null)
		[[ -n $list ]] && aur=$(wc -l <<< "$list")
	fi
	if command -v flatpak &> /dev/null; then
		list=$(flatpak remote-ls --updates 2> /dev/null)
		[[ -n $list ]] && flat=$(wc -l <<< "$list")
	fi
	left=$((repo + aur + flat))
	if ((failures)); then
		results_info+=("bad|This run: $failures step(s) failed, ${total_secs}s, at ${when#* }")
	else
		results_info+=("ok|This run: finished in ${total_secs}s, at ${when#* }")
	fi
	if [[ -s $snapshot ]]; then
		read -r up new gone < <(pacman -Q | awk -v old="$snapshot" '
			BEGIN { while ((getline l < old) > 0) { split(l, a, " "); was[a[1]] = a[2] } }
			{ if (!($1 in was)) n++; else if (was[$1] != $2) u++; seen[$1] = 1 }
			END { for (k in was) if (!(k in seen)) g++; print u + 0, n + 0, g + 0 }')
		if ((up + new + gone)); then
			results_info+=("ok|Packages: $up upgraded, $new new, $gone removed")
		else
			results_info+=('mute|Packages: none changed, they were already current')
		fi
	fi
	[[ -n $before ]] && results_info+=("mute|Run before: $before")
	if ((!checked)); then
		results_info+=('warn|Could not check what is left (offline?)')
	elif ((left)); then
		text="$left update(s) still waiting: $repo repo, $aur AUR"
		((flat)) && text+=", $flat flatpak"
		results_info+=("warn|$text")
		results_ok='! Steps finished, but updates are still waiting'
	else
		results_info+=('ok|Nothing left to update')
	fi
	# A replaced kernel removes the modules of the one that is running.
	if [[ ! -d /usr/lib/modules/$(uname -r) ]]; then
		results_info+=('warn|Reboot needed: a new kernel was installed')
	fi
}

run_steps() {
	local when before
	snapshot=$(mktemp)
	pacman -Q > "$snapshot" 2> /dev/null
	tui_run
	tui_stamp when
	before=$(tail -n 1 "$log" 2> /dev/null)
	before=${before#*> }
	before=${before/: / - }
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
	update_status "$when" "$before"
	rm -f -- "$snapshot"
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

mapfile -t sel_info < <("$dir/advisories.sh" 2> /dev/null)

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
