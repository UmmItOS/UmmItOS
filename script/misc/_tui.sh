# shellcheck shell=bash disable=SC2034
# Colourful terminal menus, sourced by update.sh and the installers: a
# checklist, a runner for the ticked steps, and a results screen. Style:
# https://style.ysap.sh/
#
# The caller fills these before calling in:
#   banner=(lines)          the title art, drawn in a gradient
#   labels descs picked     one entry per step; picked[i] is 1 when ticked
#   steps                   a function name per step (not for the checklist)
#   tags                    optional text at the right of a row
#   sel_title sel_box       the checklist's heading and box title
#   sel_hint                the key hint under it
#   choices                 the "What next?" entries
#   results_notes           optional lines under the results
#   results_info            optional "Status" box under the results, one
#                           "tone|text" entry per row: ok, warn, bad or mute
#   sel_info                the same kind of rows, in an "Arch news" box
#                           above the checklist
# A row may end in a tab and an https link: the row then is a link the terminal
# can open (OSC 8; in kitty, ctrl+shift+click).
# Hooks, all optional, named in:
#   tui_key_hook            called with the key the checklist did not use;
#                           returns 0 when it handled it
#   tui_step_hook           called with the step's index before it runs
#   tui_idle_hook           called every tui_poll seconds while the checklist
#                           waits for a key; returns 0 when something changed
#                           and the screen should be drawn again
# UMMITOS_DRY_RUN=1 makes tui_run pretend: nothing is executed.

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

banner=()
labels=()
descs=()
picked=()
tags=()
steps=()
choices=()
results_notes=()
results_info=()
sel_info=()

sel_title='Pick what to do'
sel_box='Steps'
sel_hint='↑/↓ move · space tick · a all/none · enter run · q quit'
results_ok='All done'
results_bad='Finished with %d failed step(s)'
stop_on_fail=0
tui_key_hook=
tui_step_hook=
tui_idle_hook=
# Seconds the checklist waits for a key before the idle hook runs; empty waits for ever.
tui_poll=

tui_on=0
cols=80
width=60
out=
lead=
cursor=0
note=
key=

res_label=()
res_ok=()
res_secs=()
total_secs=0
failures=0
choice=0
chosen=0

tui_enter() {
	((tui_on)) && return
	tui_on=1
	printf '\e[?1049h\e[?25l'
}

tui_leave() {
	((tui_on)) || return 0
	tui_on=0
	printf '\e[?25h\e[?1049l'
}

tui_start() {
	trap tui_leave EXIT
	trap 'exit 130' INT TERM
	trap : WINCH
}

# tui_margin OUTER INNER VAR: the spaces that centre INNER within OUTER.
tui_margin() {
	local m=$((($1 - $2) / 2))
	printf -v "$3" '%*s' "$((m > 0 ? m : 0))" ''
}

# tui_repeat CHAR COUNT VAR
tui_repeat() {
	local s
	printf -v s '%*s' "$2" ''
	printf -v "$3" '%s' "${s// /$1}"
}

tui_measure() {
	local size
	size=$(stty size 2> /dev/null)
	cols=${size#* }
	[[ $cols =~ ^[0-9]+$ ]] || cols=80
	width=$((cols - 4))
	((width > 72)) && width=72
	((width < 44)) && width=44
	tui_margin "$cols" "$width" lead
}

tui_emit() {
	out+="$lead$1$reset"$'\n'
}

# A row inside a box; $1 is exactly the inner width wide.
tui_row() {
	tui_emit "$fg_accent│$reset$1$fg_accent│"
}

tui_top() {
	local rule
	tui_repeat ─ "$((width - 5 - ${#1}))" rule
	tui_emit "$fg_accent┌─ $bold$1$reset$fg_accent $rule┐"
}

tui_bottom() {
	local rule
	tui_repeat ─ "$((width - 2))" rule
	tui_emit "$fg_accent└$rule┘"
}

tui_blank() {
	local pad
	printf -v pad '%*s' "$((width - 2))" ''
	tui_row "$pad"
}

tui_banner() {
	local i pad shade
	out=$'\e[H\e[2J\n'
	for i in "${!banner[@]}"; do
		tui_margin "$cols" "${#banner[i]}" pad
		shade=$'\e[1;38;5;'"${gradient[i * 2 % ${#gradient[@]}]}"m
		out+="$pad$shade${banner[i]}$reset"$'\n'
	done
	out+=$'\n'
}

tui_hint() {
	tui_emit "${fg_mute}$1"
}

tui_flush() {
	printf '%s' "$out"
}

# Sets key to up, down, space, enter, all, quit, resize or other.
tui_readkey() {
	local rest status
	IFS= read -rsn1 ${tui_poll:+-t "$tui_poll"} key
	status=$?
	# 142 is read's own timeout; any other signal here is a resize.
	if ((status == 142)); then
		key=idle
		return
	elif ((status > 128)); then
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
		q | Q) key=quit ;;
	esac
}

# A screen with a message, until a key.
tui_message() {
	tui_enter
	tui_measure
	tui_banner
	tui_emit "${fg_warn}$1"
	tui_emit ''
	tui_hint 'Press any key to continue.'
	tui_flush
	read -rsn1
}

tui_wait() {
	printf '\n%sPress any key to go on...%s' "$fg_mute" "$reset"
	read -rsn1
}

# tui_info_box TITLE ROW...: a box of "tone|text" rows (ok, warn, bad, mute, or note for a line that goes with the row above).
tui_info_box() {
	local title=$1 row icon tone name text link inner=$((width - 2))
	shift
	tui_top "$title"
	for row; do
		case ${row%%|*} in
			ok) icon='✔' tone=$fg_ok ;;
			warn) icon='!' tone=$fg_warn ;;
			bad) icon='✘' tone=$fg_bad ;;
			note) icon=' ' tone=$fg_mute ;;
			*) icon='·' tone=$fg_mute ;;
		esac
		text=${row#*|}
		link=
		if [[ $text == *$'\t'* ]]; then
			link=${text#*$'\t'}
			text=${text%%$'\t'*}
		fi
		printf -v name '%-*.*s' "$((inner - 4))" "$((inner - 4))" "$text"
		# Padded and cut first: the escapes take no room on screen.
		[[ -n $link ]] && name=$'\e]8;;'$link$'\e\\'$name$'\e]8;;\e\\'
		tui_row " $tone$icon $fg_text$name "
	done
	tui_bottom
	tui_emit ''
}

tui_draw_select() {
	local i inner labw=0 descw box name desc tag
	local sel=$bg_sel$bold$fg_accent
	tui_measure
	inner=$((width - 2))
	for i in "${!labels[@]}"; do
		((${#labels[i]} > labw)) && labw=${#labels[i]}
	done
	descw=$((inner - 19 - labw))
	tui_banner
	((${#sel_info[@]})) && tui_info_box 'Arch news' "${sel_info[@]}"
	tui_emit "${fg_text}${bold}$sel_title"
	tui_emit ''
	tui_top "$sel_box"
	tui_blank
	for i in "${!labels[@]}"; do
		printf -v name '%-*s' "$labw" "${labels[i]}"
		printf -v desc '%-*.*s' "$descw" "$descw" "${descs[i]}"
		if ((picked[i])); then
			box="${fg_ok}[✔]"
		else
			box="${fg_mute}[ ]"
		fi
		printf -v tag '%-9s' "${tags[i]:-}"
		tag=$fg_warn$tag
		if ((i == cursor)); then
			tui_row "$sel ❯ $box$fg_accent $name  $fg_text$desc$tag"
		else
			tui_row "   $box$reset $fg_text$name  $fg_mute$desc$tag"
		fi
	done
	tui_blank
	tui_bottom
	tui_emit ''
	tui_emit "${fg_warn}$note"
	tui_hint "$sel_hint"
	tui_flush
}

# The checklist. Returns 0 to run what is ticked, 1 to quit.
tui_select() {
	local i any count=${#labels[@]}
	note=
	while true; do
		tui_draw_select
		while true; do
			tui_readkey
			[[ $key == idle ]] || break
			"$tui_idle_hook" && break
		done
		note=
		case $key in
			up) ((cursor = (cursor + count - 1) % count)) ;;
			down) ((cursor = (cursor + 1) % count)) ;;
			space) ((picked[cursor] = !picked[cursor])) ;;
			all)
				any=0
				for i in "${!labels[@]}"; do
					((picked[i])) && any=1
				done
				for i in "${!labels[@]}"; do
					picked[i]=$((!any))
				done
				;;
			enter)
				for i in "${!labels[@]}"; do
					((picked[i])) && return 0
				done
				note='Tick at least one first.'
				;;
			quit) return 1 ;;
			*)
				[[ -n $tui_key_hook ]] && "$tui_key_hook" "$key"
				;;
		esac
	done
}

# Runs what is ticked on the normal screen, one step at a time, because
# steps ask questions. Fills res_label, res_ok, res_secs, failures.
tui_run() {
	local i n=0 k=0 start step_start rc rule stopped=0
	res_label=()
	res_ok=()
	res_secs=()
	failures=0
	for i in "${!steps[@]}"; do
		((picked[i])) && ((n++))
	done
	tui_leave
	printf '\e[H\e[2J'
	tui_repeat ─ 40 rule
	start=$SECONDS
	for i in "${!steps[@]}"; do
		((picked[i])) || continue
		((k++))
		printf '\n%s▌ %s%s' "$fg_accent" "$reset$bold" "$fg_text"
		printf 'Step %d/%d  ' "$k" "$n"
		printf '%s%s%s\n' "$fg_accent" "${labels[i]}" "$reset"
		printf '%s%s%s\n\n' "$fg_mute" "$rule" "$reset"
		res_label+=("${labels[i]}")
		if ((stopped)); then
			res_ok+=(0)
			res_secs+=(0)
			printf '%s− skipped, an earlier step failed%s\n' \
				"$fg_mute" "$reset"
			continue
		fi
		step_start=$SECONDS
		[[ -n $tui_step_hook ]] && "$tui_step_hook" "$i"
		if [[ -n $UMMITOS_DRY_RUN ]]; then
			printf '%s(dry run) %s%s\n' \
				"$fg_mute" "${steps[i]}" "$reset"
			sleep 0.3
			rc=0
		else
			"${steps[i]}"
			rc=$?
		fi
		res_secs+=($((SECONDS - step_start)))
		if ((rc == 0)); then
			res_ok+=(1)
			printf '\n%s✔ %s finished in %ds%s\n' "$fg_ok" \
				"${labels[i]}" "${res_secs[-1]}" "$reset"
		else
			res_ok+=(0)
			((failures++))
			((stop_on_fail)) && stopped=1
			printf '\n%s✘ %s did not finish%s\n' \
				"$fg_bad" "${labels[i]}" "$reset"
		fi
	done
	total_secs=$((SECONDS - start))
}

tui_draw_results() {
	local i inner labw=0 name icon tone secs rest
	tui_measure
	inner=$((width - 2))
	for i in "${!res_label[@]}"; do
		((${#res_label[i]} > labw)) && labw=${#res_label[i]}
	done
	tui_banner
	if ((failures)); then
		# shellcheck disable=SC2059
		printf -v rest "$results_bad" "$failures"
		tui_emit "${fg_bad}${bold}$rest"
	else
		tui_emit "${fg_ok}${bold}$results_ok"
	fi
	tui_emit ''
	tui_top Results
	tui_blank
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
		tui_row " $tone$icon $fg_text$name$rest$fg_mute$secs  "
	done
	printf -v secs 'Total %ds' "$total_secs"
	printf -v rest '%*s' "$((inner - 2 - ${#secs}))" ''
	tui_blank
	tui_row " $fg_mute$rest$secs "
	tui_bottom
	tui_emit ''
	((${#results_info[@]})) && tui_info_box Status "${results_info[@]}"
	tui_top 'What next?'
	for i in "${!choices[@]}"; do
		printf -v name '%-*s' "$((inner - 4))" "${choices[i]}"
		if ((i == choice)); then
			tui_row "$bg_sel$bold$fg_accent ❯ $name "
		else
			tui_row "   $fg_text$name "
		fi
	done
	tui_bottom
	tui_emit ''
	for rest in "${results_notes[@]}"; do
		tui_emit "${fg_mute}$rest"
	done
	tui_hint '↑/↓ move · enter choose · q exit'
	tui_flush
}

# The results and what next. Sets chosen to the index picked; q picks the last.
tui_results() {
	local count=${#choices[@]}
	tui_enter
	chosen=-1
	while ((chosen < 0)); do
		tui_draw_results
		tui_readkey
		case $key in
			up) ((choice = (choice + count - 1) % count)) ;;
			down) ((choice = (choice + 1) % count)) ;;
			quit) chosen=$((count - 1)) ;;
			enter) chosen=$choice ;;
		esac
	done
}

# tui_stamp VAR: the time now, for a log line.
tui_stamp() {
	printf -v "$1" '%(%Y-%m-%d %H:%M:%S)T' -1
}
