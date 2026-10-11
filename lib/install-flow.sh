#!/usr/bin/env bash
# shellcheck disable=SC1091
# The installer's screens and steps, shared by install.sh and install-menu.sh:
# a checklist of steps, each run in turn, then how it went. Style:
# https://style.ysap.sh/

repo=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)

source "$repo/lib/common.sh"
source "$repo/lib/display-utils.sh"
source "$repo/install/install-packages.sh"
source "$repo/script/misc/_tui.sh"

banner=(
	'╦ ╦╔╦╗╔╦╗╦╔╦╗╔═╗╔═╗'
	'║ ║║║║║║║║ ║ ║ ║╚═╗'
	'╚═╝╩ ╩╩ ╩╩ ╩ ╚═╝╚═╝'
)
sel_title='What should be installed?'
sel_box='Install'
sel_hint='↑/↓ move · space tick · a all/none · enter install · q quit'
results_ok='Installed. Reboot to start the desktop'
results_bad='%d step(s) did not finish'
choices=('Reboot now' 'Change the selection' 'Exit')
choice=2
results_notes=('After the reboot: ./post-install.sh --start-config')
stop_on_fail=1

step_main() {
	display_banner_start
	install_main_packages || return 1
	enable_bluetooth
	enable_networkmanager
	retire_old_notifier
}

step_gpu() {
	install_gpu_packages
}

step_laptop() {
	is_laptop && display_laptop_banner
	install_laptop_packages
}

step_omz() {
	bash ./install/oh-my-zsh.sh
}

step_dots() {
	bash ./install/copy-config.sh
}

step_dm() {
	bash ./install/setup-dm.sh
}

# What this machine can use; steps it cannot are listed, unticked.
define_steps() {
	labels=('Main packages' 'GPU packages' 'Laptop packages' 'oh-my-zsh' 'Dotfiles' 'Login screen')
	steps=(step_main step_gpu step_laptop step_omz step_dots step_dm)
	descs=(
		'Hyprland, Quickshell, the apps'
		'AMD graphics drivers'
		'Brightness keys (brightnessctl)'
		'zsh framework and plugins'
		'Configs and scripts, asks first'
		'greetd and the UmmItOS greeter'
	)
	picked=(1 1 1 1 1 1)
	tags=('' '' '' '' '' '')
	if ! has_amdgpu; then
		picked[1]=0
		tags[1]='n/a'
		descs[1]='No AMD GPU here'
	fi
	if ! is_laptop; then
		picked[2]=0
		tags[2]='n/a'
		descs[2]='Not a laptop'
	fi
}

countdown_reboot() {
	local s
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

# run_installer [--all]: with --all the checklist is skipped and everything
# applicable is installed after one question.
run_installer() {
	local all=0
	[[ $1 == --all ]] && all=1

	if ((EUID == 0)); then
		echo "${COLOR_DARK_RED}:: Do not run the installer as root, like you would not run Hyprland as root. Use your normal user.${COLOR_RESET}"
		exit 1
	fi
	if [[ ! -f /etc/arch-release ]]; then
		echo "${COLOR_YELLOW}:: The installer only runs on Arch Linux, or an Arch based distribution such as EndeavourOS.${COLOR_RESET}"
		exit 1
	fi
	if [[ -z $UMMITOS_DRY_RUN ]] && { ! check_git || ! check_paru; }; then
		echo "${COLOR_DARK_RED}:: git and paru are needed first.${COLOR_RESET}"
		exit 1
	fi
	if [[ ! -t 0 || ! -t 1 ]]; then
		echo 'The installer needs a terminal.' >&2
		exit 1
	fi

	cd "$repo" || exit 1
	define_steps
	tui_start

	while true; do
		if ((all)); then
			clear
			prompt_installation || exit 0
		else
			tui_enter
			tui_select || exit 0
		fi
		tui_run
		tui_wait
		tui_results
		case $chosen in
			0) countdown_reboot ;;
			1) all=0 ;;
			*) exit 0 ;;
		esac
	done
}
