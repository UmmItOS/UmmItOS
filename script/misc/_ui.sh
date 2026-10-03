# shellcheck shell=bash disable=SC2034
# Sourced by the other scripts here: colours and systemd-style status lines.

COLOR_LIGHT_BLUE='\e[94m'
COLOR_GREEN='\e[32m'
COLOR_DARK_RED='\e[31m'
COLOR_GREY='\e[90m'
COLOR_RESET='\e[0m'

print_status() {
    local status="$1"
    local message="$2"
    if [[ "${status}" == "SUCCESS" ]]; then
        echo -e "[ ${COLOR_GREEN}SUCCESS${COLOR_RESET} ] ${message}"
    else
        echo -e "[ ${COLOR_DARK_RED}FAILED${COLOR_RESET} ] ${message}"
    fi
}
