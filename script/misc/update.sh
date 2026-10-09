#!/usr/bin/env bash
# Upgrade UmmItOS: pick what to update in a colourful menu, watch each step
# run, then read how it went. Style: https://style.ysap.sh/

dir=${BASH_SOURCE[0]%/*}
[[ $dir == "${BASH_SOURCE[0]}" ]] && dir=.
# shellcheck source=script/misc/_ui.sh
source "$dir/_ui.sh"

log=$HOME/script/misc/update.log

reset=$'\e[0m'
bold=$'\e[1m'
fg_accent=$'\e[38;5;141m'
fg_ok=$'\e[38;5;114m'
fg_bad=$'\e[38;5;203m'
fg_warn=$'\e[38;5;221m'
fg_text=$'\e[38;5;252m'
fg_mute=$'\e[38;5;245m'
bg_sel=$'\e[48;5;54m'
gradient=(99 105 111 117 123)

banner=(
	'╦ ╦┌─┐┌─┐┬─┐┌─┐┌┬┐┌─┐  ╔═╗┬ ┬┌─┐┌┬┐┌─┐┌┬┐'
	'║ ║├─┘│ ┬├┬┘├─┤ ││├┤   ╚═╗└┬┘└─┐ │ ├┤ │││'
	'╚═╝┴  └─┘┴└─┴ ┴─┴┘└─┘  ╚═╝ ┴ └─┘ ┴ └─┘┴ ┴'
)

labels=()
descs=()
steps=()
picked=()

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
done

on_screen=0
cols=80
width=60
out=
lead=

enter_screen() {
	(( on_screen )) && return
	on_screen=1
	printf '\e[?1049h\e[?25l'
}

leave_screen() {
	(( on_screen )) || return 0
	on_screen=0
	printf '\e[?25h\e[?1049l'
}

trap leave_screen EXIT
trap 'exit 130' INT TERM
trap : WINCH

measure() {
	local size
	size=$(stty size 2> /dev/null)
	cols=${size#* }
	[[ $cols =~ ^[0-9]+$ ]] || cols=80
	width=$((cols - 4))
	((width > 72)) && width=72
	((width < 44)) && width=44
	margin "$cols" "$width" lead
}

margin() {
	local m=$((($1 - $2) / 2))
	printf -v "$3" '%*s' "$((m > 0 ? m : 0))" ''
}

repeat() {
	local s
	printf -v s '%*s' "$2" ''
	printf -v "$3" '%s' "${s// /$1}"
}

emit() {
	out+="$lead$1$reset"$'\n'
}

row() {
	emit "$fg_accent│$reset$1$fg_accent│"
}

top() {
	local rule
	repeat ─ "$((width - 5 - ${#1}))" rule
	emit "$fg_accent┌─ $bold$1$reset$fg_accent $rule┐"
}

bottom() {
	local rule
	repeat ─ "$((width - 2))" rule
	emit "$fg_accent└$rule┘"
}

blank_row() {
	local pad
	printf -v pad '%*s' "$((width - 2))" ''
	row "$pad"
}

draw_banner() {
	local i pad shade
	out=$'\e[H\e[2J\n'
	for i in "${!banner[@]}"; do
		margin "$cols" "${#banner[i]}" pad
		shade=$'\e[1;38;5;'"${gradient[i * 2]}"m
		out+="$pad$shade${banner[i]}$reset"$'\n'
	done
	out+=$'\n'
}

hint() {
	emit "${fg_mute}$1"
}

flush() {
	printf '%s' "$out"
}

read_key() {
	local rest status
	IFS= read -rsn1 key
	status=$?
	if ((status > 128)); then
		key=resize
		return
	fi
	case $key in
		$'\e')
			rest=
			read -rsn2 -t 0.05 rest
			case $rest in
				'[A') key=up ;;
				'[B') key=down ;;
				*) key=quit ;;
			esac
			;;
		k | K) key=up ;;
		j | J) key=down ;;
		' ') key=space ;;
		'') key=enter ;;
		a | A) key=all ;;
		y | Y) key=yes ;;
		q | Q | n | N) key=quit ;;
		*) key=other ;;
	esac
}

cursor=0
note=

draw_select() {
	local i inner labw=0 descw box name desc
	local sel=$bg_sel$bold$fg_accent
	local tag
	measure
	inner=$((width - 2))
	for i in "${!labels[@]}"; do
		((${#labels[i]} > labw)) && labw=${#labels[i]}
	done
	descw=$((inner - 19 - labw))
	draw_banner
	emit "${fg_text}${bold}What should be updated?"
	emit ''
	top Updates
	blank_row
	for i in "${!labels[@]}"; do
		printf -v name '%-*s' "$labw" "${labels[i]}"
		printf -v desc '%-*.*s' "$descw" "$descw" "${descs[i]}"
		if ((picked[i])); then
			box="${fg_ok}[✔]"
		else
			box="${fg_mute}[ ]"
		fi
		tag='         '
		((yes[i])) && tag='auto-yes '
		tag=$fg_warn$tag
		if ((i == cursor)); then
			row "$sel ❯ $box$fg_accent $name  $fg_text$desc$tag"
		else
			row "   $box$reset $fg_text$name  $fg_mute$desc$tag"
		fi
	done
	blank_row
	bottom
	emit ''
	if [[ -n $note ]]; then
		emit "${fg_warn}$note"
	else
		emit ''
	fi
	hint '↑/↓ move · space tick · y auto-yes · a all/none · enter run'
	flush
}

select_steps() {
	local i any count=${#steps[@]}
	note=
	while true; do
		draw_select
		read_key
		note=
		case $key in
			up) ((cursor = (cursor + count - 1) % count)) ;;
			down) ((cursor = (cursor + 1) % count)) ;;
			space) ((picked[cursor] = !picked[cursor])) ;;
			yes)
				if [[ ${steps[cursor]} == update_omz ]]; then
					note='oh-my-zsh has nothing to confirm.'
				else
					((yes[cursor] = !yes[cursor]))
				fi
				;;
			all)
				any=0
				for i in "${!steps[@]}"; do
					((picked[i])) && any=1
				done
				for i in "${!steps[@]}"; do
					picked[i]=$((!any))
				done
				;;
			enter)
				for i in "${!steps[@]}"; do
					((picked[i])) && return 0
				done
				note='Tick at least one update first.'
				;;
			quit) return 1 ;;
		esac
	done
}

res_label=()
res_ok=()
res_secs=()
total_secs=0
failures=0

stamp() {
	printf -v "$1" '%(%Y-%m-%d %H:%M:%S)T' -1
}

run_steps() {
	local i n=0 k=0 start step_start rc rule when
	res_label=()
	res_ok=()
	res_secs=()
	failures=0
	for i in "${!steps[@]}"; do
		((picked[i])) && ((n++))
	done
	leave_screen
	printf '\e[H\e[2J'
	repeat ─ 40 rule
	start=$SECONDS
	for i in "${!steps[@]}"; do
		((picked[i])) || continue
		((k++))
		printf '\n%s▌ %s%s' "$fg_accent" "$reset$bold" "$fg_text"
		printf 'Step %d/%d  ' "$k" "$n"
		printf '%s%s%s\n' "$fg_accent" "${labels[i]}" "$reset"
		printf '%s%s%s\n\n' "$fg_mute" "$rule" "$reset"
		step_start=$SECONDS
		assume=${yes[i]}
		"${steps[i]}"
		rc=$?
		res_label+=("${labels[i]}")
		res_secs+=($((SECONDS - step_start)))
		if ((rc == 0)); then
			res_ok+=(1)
			printf '\n%s✔ %s finished in %ds%s\n' "$fg_ok" \
				"${labels[i]}" "${res_secs[-1]}" "$reset"
		else
			res_ok+=(0)
			((failures++))
			printf '\n%s✘ %s did not finish%s\n' \
				"$fg_bad" "${labels[i]}" "$reset"
		fi
	done
	total_secs=$((SECONDS - start))
	stamp when
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
	printf '\n%sPress any key for the results...%s' "$fg_mute" "$reset"
	read -rsn1
}

choices=('Reboot now' 'Run again' 'Change the selection' 'Open a shell' 'Exit')
choice=4
action=

draw_results() {
	local i inner labw=0 name icon tone secs rest
	measure
	inner=$((width - 2))
	for i in "${!res_label[@]}"; do
		((${#res_label[i]} > labw)) && labw=${#res_label[i]}
	done
	draw_banner
	if ((failures)); then
		emit "${fg_bad}${bold}Finished with $failures failed step(s)"
	else
		emit "${fg_ok}${bold}Everything is up to date"
	fi
	emit ''
	top Results
	blank_row
	for i in "${!res_label[@]}"; do
		printf -v name '%-*s' "$labw" "${res_label[i]}"
		if ((res_ok[i])); then
			icon='✔'
			tone=$fg_ok
		else
			icon='✘'
			tone=$fg_bad
		fi
		printf -v secs '%ds' "${res_secs[i]}"
		printf -v rest '%*s' "$((inner - 5 - labw - ${#secs}))" ''
		row " $tone$icon $fg_text$name$rest$fg_mute$secs  "
	done
	printf -v secs 'Total %ds' "$total_secs"
	printf -v rest '%*s' "$((inner - 2 - ${#secs}))" ''
	blank_row
	row " $fg_mute$rest$secs "
	bottom
	emit ''
	top 'What next?'
	for i in "${!choices[@]}"; do
		printf -v name '%-*s' "$((inner - 4))" "${choices[i]}"
		if ((i == choice)); then
			row "$bg_sel$bold$fg_accent ❯ $name "
		else
			row "   $fg_text$name "
		fi
	done
	bottom
	emit ''
	hint '↑/↓ move · enter choose · q exit'
	flush
}

show_results() {
	local count=${#choices[@]}
	enter_screen
	action=
	while [[ -z $action ]]; do
		draw_results
		read_key
		case $key in
			up) ((choice = (choice + count - 1) % count)) ;;
			down) ((choice = (choice + 1) % count)) ;;
			quit) action='exit' ;;
			enter)
				case $choice in
					0) action=reboot ;;
					1) action=again ;;
					2) action=menu ;;
					3) action=shell ;;
					4) action='exit' ;;
				esac
				;;
		esac
	done
}

countdown_reboot() {
	local s
	say Update Rebooting 'The system will reboot in 5 seconds.' critical
	for s in 5 4 3 2 1; do
		measure
		out=$'\e[H\e[2J\n\n'
		emit "${fg_warn}${bold}Rebooting in $s..."
		emit "${fg_mute}Press Ctrl+C to cancel."
		flush
		sleep 1
	done
	leave_screen
	systemctl reboot
}

if [[ ! -t 0 || ! -t 1 ]]; then
	echo 'update.sh needs a terminal.' >&2
	exit 1
fi

if ((${#steps[@]} == 0)); then
	enter_screen
	measure
	draw_banner
	emit "${fg_warn}Nothing on this system to update from here."
	emit ''
	hint 'Press any key to exit.'
	flush
	read -rsn1
	exit 0
fi

while true; do
	enter_screen
	select_steps || exit 0
	action=again
	while [[ $action == again ]]; do
		run_steps
		show_results
	done
	case $action in
		reboot) countdown_reboot ;;
		shell)
			leave_screen
			exec "${SHELL:-/bin/bash}"
			;;
		exit) exit 0 ;;
	esac
done
