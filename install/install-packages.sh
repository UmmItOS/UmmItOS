#!/usr/bin/env bash
# shellcheck disable=SC1091

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Source library functions
source "$PARENT_DIR/lib/common.sh"
source "$PARENT_DIR/lib/display-utils.sh"

# Function to read packages from a file into an array
read_packages_from_file() {
    local file_path="$1"
    local -n packages_array=$2

    packages_array=()

    if [[ ! -f "$file_path" ]]; then
        echo "${COLOR_DARK_RED}:: Package file not found: $file_path${COLOR_RESET}"
        return 1
    fi

    # Read packages from the file, skipping empty lines
    while IFS= read -r package; do
        # Check if the line is not empty
        if [[ -n "$package" ]]; then
            packages_array+=("$package")
        fi
    done < "$file_path"

    return 0
}

# Function to install packages with paru
install_packages_with_paru() {
    local -n packages=$1
    local package_type="$2"

    local total_packages=${#packages[@]}

    if (( total_packages == 0 )); then
        echo "${COLOR_YELLOW}:: No ${package_type} packages to install.${COLOR_RESET}"
        return 0
    fi

    if prompt_yna ":: Install these ${package_type} packages? - Total Package (${total_packages})"; then
        paru -S "${packages[@]}"

        pause_and_continue "${package_type} packages installed completed. Press any key to keep going :)"
        clear
    else
        echo "${COLOR_YELLOW}:: Skipping ${package_type} package installation.${COLOR_RESET}"

        pause_and_continue "${package_type} packages installation skipped. Press any key to keep going :)"
        clear
    fi
}

# Function to display packages in columns
display_packages() {
    local -n packages=$1
    local package_type="$2"

    echo "${COLOR_GREEN}:: ${package_type} packages to be installed${COLOR_RESET}"

    local total_packages=${#packages[@]}

    if (( total_packages == 0 )); then
        echo "${COLOR_YELLOW}   No packages found.${COLOR_RESET}"
        return 1
    fi

    mapfile -t formatted_packages < <(printf "%s\n" "${packages[@]}" | column)
    printf "${COLOR_GREY}%s${COLOR_RESET}\n" "${formatted_packages[@]}"

    return 0
}

# Function to install main packages
install_main_packages() {
    # shellcheck disable=SC2034
    local main_packages=()

    if read_packages_from_file "./install/packages_main" main_packages; then
        display_packages main_packages "Main"
        install_packages_with_paru main_packages "main"
    fi
}

# Function to install GPU packages
install_gpu_packages() {
    if ! has_amdgpu; then
        echo "${COLOR_YELLOW}:: No AMD GPU detected. Skipping GPU package installation.${COLOR_RESET}"
        return 0
    fi

    # shellcheck disable=SC2034
    local gpu_packages=()

    if read_packages_from_file "./install/packages_gpu" gpu_packages; then
        display_packages gpu_packages "GPU"
        install_packages_with_paru gpu_packages "GPU"
    fi
}

# Function to install laptop packages
install_laptop_packages() {
    if ! is_laptop; then
        echo "${COLOR_YELLOW}:: Not a laptop. Skipping laptop package installation.${COLOR_RESET}"
        return 0
    fi

    # shellcheck disable=SC2034
    local laptop_packages=()

    if read_packages_from_file "./install/packages_laptop" laptop_packages; then
        display_packages laptop_packages "Laptop"
        install_packages_with_paru laptop_packages "laptop"
    fi
}

main() {
    # Display the banner
    display_banner_start

    # Install main packages
    install_main_packages

    # Install GPU packages
    install_gpu_packages

    # Install laptop packages
    if is_laptop; then
        display_laptop_banner
        install_laptop_packages
    fi
}

main