#!/usr/bin/env bash
# Opened in kitty by the settings panel's Packages page with the packages it found missing.

# shellcheck source=script/misc/_ui.sh
source "$(dirname "$0")/_ui.sh"

log="$HOME/script/misc/install-packages.log"

# Banner for installing packages
echo -e "${COLOR_LIGHT_BLUE}"
cat << "EOF"
╦┌┐┌┌─┐┌┬┐┌─┐┬  ┬    ╔═╗┌─┐┌─┐┬┌─┌─┐┌─┐┌─┐┌─┐
║│││└─┐ │ ├─┤│  │    ╠═╝├─┤│  ├┴┐├─┤│ ┬├┤ └─┐
╩┘└┘└─┘ ┴ ┴ ┴┴─┘┴─┘  ╩  ┴ ┴└─┘┴ ┴┴ ┴└─┘└─┘└─┘

EOF
echo -e "${COLOR_RESET}"

if (( $# == 0 )); then
    echo -e "${COLOR_GREEN}Nothing to install: every UmmItOS package is already here.${COLOR_RESET}"
    read -rp "Press Enter to close..."
    exit 0
fi

echo -e "${COLOR_GREEN}These UmmItOS packages are missing from this system (${#}):${COLOR_RESET}"
printf "  • %s\n" "$@"
echo ""
echo -e "${COLOR_GREY}paru asks for your password, then shows what it will download and waits for your yes.${COLOR_RESET}"
echo ""
echo -e "[${COLOR_GREEN} RUNNING ${COLOR_RESET}] Installing ${#} package(s) via paru"

start_time=$(date +%s)
if paru -S --needed "$@"; then
    result=SUCCESS
    message="Installed ${#} missing package(s), plus anything they depend on"
else
    result=FAILED
    message="paru did not finish (cancelled or failed); see the output above"
fi
total_duration=$(( $(date +%s) - start_time ))

echo ""
print_status "$result" "$message"
echo -e "Total duration: ${COLOR_GREEN}${total_duration}${COLOR_RESET} seconds"
echo "<NOTICE> $(date +"%Y-%m-%d %H:%M:%S"): ${result}: $* (${total_duration} seconds)" >> "$log"

echo ""
echo -e "${COLOR_GREY}The Packages page checks again when this window closes.${COLOR_RESET}"
read -rp "Press Enter to close..."
