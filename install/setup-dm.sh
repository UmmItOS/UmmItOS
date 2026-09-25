#!/usr/bin/env bash
# shellcheck disable=SC1091

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Source library functions
source "$PARENT_DIR/lib/common.sh"
source "$PARENT_DIR/lib/display-utils.sh"

greeter_dir=/usr/share/ummitos/greeter
# Written by the user's shell (GreeterSync) and read by the greeter, which cannot read the user's home.
shared_dir=/var/lib/ummitos-greeter

# The greeter user's home is /, which it cannot write, so quickshell keeps its cache and state in /tmp;
# cage draws no title bars, so Qt must not draw its own.
greeter_command() {
    printf 'env QT_WAYLAND_DISABLE_WINDOWDECORATION=1 XDG_CACHE_HOME=/tmp/ummitos-greeter XDG_STATE_HOME=/tmp/ummitos-greeter XDG_DATA_HOME=/tmp/ummitos-greeter cage -s -- qs -p %s' "$greeter_dir"
}

# The QML greeter, its config for greetd, and the keyring unlock GDM used to do at login.
install_greeter() {
    if ! command_exists greetd || ! command_exists cage; then
        echo "${COLOR_DARK_RED}:: greetd or cage is not installed. Install the main packages first.${COLOR_RESET}"
        return 1
    fi

    echo "${COLOR_BLUE}:: Installing the login screen to ${greeter_dir}...${COLOR_RESET}"
    sudo mkdir -p "$greeter_dir" &&
        sudo cp -rL "$PARENT_DIR/configs/greeter/." "$greeter_dir/" || return 1

    sudo mkdir -p "$shared_dir" &&
        sudo chown "$USER:" "$shared_dir" &&
        chmod 755 "$shared_dir" || return 1
    printf "%s" "$USER" > "$shared_dir/user"
    # Until the shell's first sync, any wallpaper will do.
    if [[ ! -f "$shared_dir/wallpaper" ]]; then
        local first
        first=$(find "$HOME/.wallpaper" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | head -n 1)
        [[ -n "$first" ]] && cp -f "$first" "$shared_dir/wallpaper"
    fi

    if [[ -f /etc/greetd/config.toml ]]; then
        sudo cp /etc/greetd/config.toml "/etc/greetd/config.toml.bak.$(date +%Y%m%d-%H%M%S)"
    fi
    sudo tee /etc/greetd/config.toml > /dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "$(greeter_command)"
user = "greeter"
EOF

    # GDM unlocked the keyring (browser passwords) at login; greetd needs the same PAM lines.
    if [[ -f /usr/lib/security/pam_gnome_keyring.so ]] && ! grep -q pam_gnome_keyring /etc/pam.d/greetd; then
        sudo sed -i '/^auth.*include/a auth       optional     pam_gnome_keyring.so' /etc/pam.d/greetd
        sudo sed -i '/^session.*include/a session    optional     pam_gnome_keyring.so auto_start' /etc/pam.d/greetd
    fi
    echo "${COLOR_GREEN}:: Login screen installed.${COLOR_RESET}"
}

# Hand the login over to greetd; GDM stays installed, so going back is one command.
enable_greetd() {
    if systemctl is-enabled greetd.service &> /dev/null; then
        echo "${COLOR_GREEN}:: greetd is already the login manager.${COLOR_RESET}"
        return 0
    fi
    if ! prompt_yna ":: Use greetd with the UmmItOS login screen from the next boot?"; then
        echo "${COLOR_YELLOW}:: You can switch later with 'sudo systemctl enable greetd'.${COLOR_RESET}"
        return 0
    fi
    if systemctl is-enabled gdm.service &> /dev/null; then
        sudo systemctl disable gdm.service
    fi
    if sudo systemctl enable greetd.service; then
        echo "${COLOR_GREEN}:: greetd enabled. To go back: sudo systemctl disable greetd && sudo systemctl enable gdm${COLOR_RESET}"
    else
        echo "${COLOR_DARK_RED}:: Could not enable greetd.${COLOR_RESET}"
        return 1
    fi
}

main() {
    display_manager_banner
    install_greeter && enable_greetd
    read -rp "Press Enter to continue..."
}

main
