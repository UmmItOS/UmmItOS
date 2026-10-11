#!/usr/bin/env bash
# Checks that this machine really runs what the repo holds: the shell loaded
# without errors, the live copies of the scripts and keybinds are current, the
# packages and submodules are there. Prints one line per check:
#   ok|warn|fail<TAB>group<TAB>title<TAB>detail
# and "done<TAB>ok<TAB>warn<TAB>fail" at the end. With --fix scripts it copies
# the repo's scripts over ~/script (the repo is their source).
# Style: https://style.ysap.sh/

home_cfg=${XDG_CONFIG_HOME:-$HOME/.config}
state=${XDG_STATE_HOME:-$HOME/.local/state}/ummitos
ok=0
warn=0
fail=0
repo=

# The repo: where the shell's config link points, else where the installer
# recorded it, else ~/UmmItOS.
find_repo() {
	local link dir
	link=$(readlink -f "$home_cfg/quickshell/ummitos" 2> /dev/null)
	if [[ -n $link && -d ${link%/configs/quickshell}/.git ]]; then
		repo=${link%/configs/quickshell}
	elif [[ -f $state/repo-path ]] && [[ -d $(< "$state/repo-path")/.git ]]; then
		repo=$(< "$state/repo-path")
	elif [[ -d $HOME/UmmItOS/.git ]]; then
		repo=$HOME/UmmItOS
	fi
	[[ -n $repo ]] && return 0
	for dir in "$HOME"/*/UmmItOS "$HOME"/*/*/UmmItOS; do
		[[ -d $dir/.git ]] && repo=$dir && return 0
	done
	return 1
}

# say STATUS GROUP TITLE DETAIL
say() {
	case $1 in
		ok) ((ok++)) ;;
		warn) ((warn++)) ;;
		fail) ((fail++)) ;;
	esac
	printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"
}

check_repo() {
	local branch behind
	say ok Repository 'Found' "${repo/#$HOME/~}"
	branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2> /dev/null)
	if [[ -n $(git -C "$repo" status --porcelain 2> /dev/null) ]]; then
		say warn Repository 'Uncommitted changes' 'The folder has edits that are not committed'
	else
		say ok Repository 'Clean' "On $branch, nothing uncommitted"
	fi
	behind=$(git -C "$repo" rev-list --count 'HEAD..@{upstream}' 2> /dev/null)
	if [[ $behind =~ ^[0-9]+$ ]] && ((behind > 0)); then
		say warn Repository 'Behind the remote' "$behind commit(s) to pull"
	fi
	local sub
	while read -r sub; do
		[[ -z $sub ]] && continue
		if [[ -z $(ls -A "$repo/$sub" 2> /dev/null) ]]; then
			say fail Repository "Submodule $sub" 'Empty: run git submodule update --init'
		else
			say ok Repository "Submodule $sub" 'Present'
		fi
	done < <(git -C "$repo" config --file .gitmodules --get-regexp path 2> /dev/null | awk '{print $2}')
}

check_shell() {
	local link want log last
	link=$(readlink -f "$home_cfg/quickshell/ummitos" 2> /dev/null)
	want=$repo/configs/quickshell
	if [[ ! -e $home_cfg/quickshell/ummitos ]]; then
		say fail Shell 'Config link missing' "$home_cfg/quickshell/ummitos does not exist"
	elif [[ $link == "$want" ]]; then
		say ok Shell 'Runs the repo' 'The config is linked to the repo, so a pull updates it'
	elif [[ -n $(diff -rq "$want" "$link" 2> /dev/null) ]]; then
		say warn Shell 'Installed copy differs' 'It is a copy, not a link: run install/copy-config.sh again'
	else
		say ok Shell 'Installed copy' 'Same as the repo'
	fi
	if ! command -v qs &> /dev/null; then
		say fail Shell 'quickshell not installed' 'paru -S quickshell'
		return
	fi
	if ! qs list 2> /dev/null | grep -q .; then
		say fail Shell 'Not running' 'Start it: qs -c ummitos -d'
		return
	fi
	log=$(qs log -c ummitos 2> /dev/null)
	last=$(grep -E 'Configuration Loaded|Failed to load configuration' <<< "$log" | tail -n 1)
	if [[ $last == *Loaded* ]]; then
		say ok Shell 'Loaded' 'The last load had no errors'
	else
		say fail Shell 'Failed to load' "$(grep -A2 'Failed to load' <<< "$log" | tail -n 2 | tr '\n' ' ' | sed 's/\x1b\[[0-9;]*m//g')"
	fi
	if awk '/Configuration Loaded/ { n = 0; next } { n++ } /ReferenceError|TypeError/ { bad = 1 } END { exit !bad }' <<< "$log" \
		&& awk '/Configuration Loaded/ { bad = 0; next } /ReferenceError|TypeError/ { bad = 1 } END { exit !bad }' <<< "$log"; then
		say warn Shell 'Runtime errors' 'qs log -c ummitos shows ReferenceError or TypeError after the last load'
	fi
}

check_scripts() {
	local src rel live stale=0 missing=0
	while IFS= read -r -d '' src; do
		rel=${src#"$repo/script/"}
		live=$HOME/script/$rel
		if [[ ! -e $live ]]; then
			((missing++))
			say fail Scripts "$rel" 'Missing from ~/script'
		elif ! cmp -s "$src" "$live"; then
			((stale++))
			say warn Scripts "$rel" 'Differs from the repo'
		fi
	done < <(find "$repo/script" -type f ! -name '*.log' ! -name .gitignore -print0 | sort -z)
	if ((stale + missing == 0)); then
		say ok Scripts 'Live scripts' 'Every script in ~/script matches the repo'
	else
		say warn Scripts 'Fixable' 'doctor.sh --fix scripts copies the repo'"'"'s scripts to ~/script'
	fi
}

# Every bind of the repo's shortcuts must be in the live file: the live copy is
# the user's own, so only missing binds are reported, never overwritten.
check_hypr() {
	local live=$home_cfg/hypr/hyprland/shortcuts.lua desc missing=0
	if [[ ! -f $live ]]; then
		say fail Hyprland 'shortcuts.lua missing' "$live does not exist"
		return
	fi
	while IFS= read -r desc; do
		if ! grep -qF "\"$desc\"" "$live"; then
			((missing++))
			say warn Hyprland "Keybind: $desc" 'In the repo, not in your shortcuts.lua; add it by hand'
		fi
	done < <(grep -E '^bind\(.*\)$' "$repo/configs/hypr/hyprland/shortcuts.lua" | sed -E 's/.*, "([^"]*)"(, *\{.*)?\)$/\1/')
	((missing == 0)) && say ok Hyprland 'Keybinds' 'Every shell keybind is in your shortcuts.lua'
	if command -v Hyprland &> /dev/null; then
		if Hyprland --verify-config -c "$home_cfg/hypr/hyprland.lua" 2>&1 | grep -q 'config ok'; then
			say ok Hyprland 'Config' 'Hyprland accepts hyprland.lua'
		else
			say fail Hyprland 'Config' 'Hyprland --verify-config reports problems'
		fi
	fi
}

check_packages() {
	local pkg name missing=()
	while IFS= read -r pkg; do
		[[ -z $pkg ]] && continue
		name=${pkg#*/}
		pacman -Qq "$name" &> /dev/null || missing+=("$name")
	done < "$repo/install/packages_main"
	if ((${#missing[@]} == 0)); then
		say ok Packages 'Installed' 'Every package of packages_main is here'
	else
		say fail Packages "${#missing[@]} missing" "${missing[*]}"
	fi
}

check_system() {
	local unit
	for unit in bluetooth NetworkManager; do
		if systemctl is-enabled "$unit.service" &> /dev/null; then
			say ok System "$unit" 'Enabled at boot'
		else
			say warn System "$unit" "Not enabled: sudo systemctl enable --now $unit"
		fi
	done
	if [[ $(systemctl --user is-enabled swaync.service 2>&1) != masked ]] && command -v swaync &> /dev/null; then
		say warn System 'swaync' 'Installed and not masked: it can steal the notification name'
	fi
	local dir
	for dir in kitty fastfetch yazi mpv; do
		if [[ -d $home_cfg/$dir ]]; then
			say ok Config "$dir" 'Present in ~/.config'
		else
			say warn Config "$dir" 'Missing from ~/.config: install/copy-config.sh copies it'
		fi
	done
}

# The commands the shell and its scripts call; one missing breaks one feature.
check_tools() {
	local cmd missing=()
	for cmd in qs hyprctl grim wl-copy wl-paste cliphist cava tesseract sqlite3 notify-send pw-play jq magick zbarimg wlrctl hypridle; do
		command -v "$cmd" &> /dev/null || missing+=("$cmd")
	done
	if ((${#missing[@]} == 0)); then
		say ok Tools 'Commands' 'Every command the shell calls is installed'
	else
		say warn Tools "${#missing[@]} missing" "${missing[*]}: the feature using each will not work"
	fi
}

# The input method: running, the UmmItOS popup theme chosen, a language beside English.
check_input() {
	local conf=$home_cfg/fcitx5/conf/classicui.conf theme
	if ! command -v fcitx5 &> /dev/null; then
		say fail Input 'fcitx5 not installed' 'paru -S fcitx5'
		return
	fi
	if pgrep -x fcitx5 &> /dev/null; then
		say ok Input 'fcitx5' 'Running'
	else
		say fail Input 'fcitx5' 'Not running: start it with fcitx5 -d'
	fi
	theme=$(grep -m1 '^Theme=' "$conf" 2> /dev/null | cut -d= -f2)
	if [[ $theme == ummitos ]]; then
		say ok Input 'Popup theme' 'The UmmItOS theme is chosen'
	else
		say warn Input 'Popup theme' "Theme is '${theme:-unset}', not ummitos: link configs/fcitx5/themes/ummitos into ~/.local/share/fcitx5/themes and set Theme= in classicui.conf"
	fi
	if [[ -e $HOME/.local/share/fcitx5/themes/ummitos/theme.conf ]]; then
		say ok Input 'Theme files' 'Found in ~/.local/share/fcitx5/themes'
	else
		say warn Input 'Theme files' 'Missing from ~/.local/share/fcitx5/themes'
	fi
	if [[ $(grep -c '^Name=' "$home_cfg/fcitx5/profile" 2> /dev/null) -ge 3 ]]; then
		say ok Input 'Input methods' 'A second input method is set up'
	else
		say warn Input 'Input methods' 'Only the keyboard: add Chinese in fcitx5-configtool'
	fi
}

# Things the repo ships and you may have changed: only differences are reported, never overwritten.
check_dotfiles() {
	local pair src dst
	for pair in configs/kitty/kitty.conf:kitty/kitty.conf configs/fastfetch/config.jsonc:fastfetch/config.jsonc configs/starship.toml:starship.toml configs/hypr/hyprland/permissions.lua:hypr/hyprland/permissions.lua configs/hypr/hyprland/autostart.lua:hypr/hyprland/autostart.lua; do
		src=$repo/${pair%%:*}
		dst=$home_cfg/${pair#*:}
		if [[ ! -e $dst ]]; then
			say warn Dotfiles "${pair#*:}" 'Missing from ~/.config'
		elif cmp -s "$src" "$dst"; then
			say ok Dotfiles "${pair#*:}" 'Same as the repo'
		else
			say warn Dotfiles "${pair#*:}" 'Differs from the repo: yours may be on purpose; diff it to see'
		fi
	done
	local entry
	for entry in 'qs -c ummitos' 'wl-paste --watch' fcitx5 hypridle; do
		if grep -qF "$entry" "$home_cfg/hypr/hyprland/autostart.lua" 2> /dev/null; then
			say ok Autostart "$entry" 'Started at login'
		else
			say warn Autostart "$entry" 'Not in your autostart.lua'
		fi
	done
}

if [[ $1 == --fix ]]; then
	find_repo || exit 1
	if [[ $2 == scripts ]]; then
		while IFS= read -r -d '' src; do
			rel=${src#"$repo/script/"}
			[[ $rel == */* ]] && mkdir -p "$HOME/script/${rel%/*}"
			install -m "$(stat -c %a "$src")" "$src" "$HOME/script/$rel"
		done < <(find "$repo/script" -type f ! -name '*.log' ! -name .gitignore -print0)
		echo 'fixed	scripts'
	fi
	exit 0
fi

if ! find_repo; then
	say fail Repository 'Not found' 'No UmmItOS folder: run the installer first'
	printf 'done\t%d\t%d\t%d\n' "$ok" "$warn" "$fail"
	exit 0
fi

check_repo
check_shell
check_scripts
check_hypr
check_packages
check_tools
check_input
check_dotfiles
check_system
printf 'done\t%d\t%d\t%d\n' "$ok" "$warn" "$fail"
