#!/usr/bin/env bash

# Check the distribution name and print the package manager
# with a custom face and message :)

# Define a function to print the message
print_message() {
    local manager="$1"
    echo "🐧 Ayo, $manager :) 🐧"
}

# Check the distribution name and print the package manager
case "$(grep ^ID= /etc/os-release)" in
    ID=arch*) print_message "pacman -Syu" ;;
    ID=kali*) print_message "apt upgrade" ;;
    ID=fedora*) print_message "dnf upgrade" ;;
    ID=gentoo*) print_message "emerge" ;;
    ID=ubuntu*|ID=debian*) print_message "apt upgrade" ;;
    ID=parrot*) print_message "apt upgrade" ;;
    ID=void*) print_message "xbps-install" ;;
    ID=alpine*) print_message "apk add" ;;
    ID=manjaro*) print_message "pacman -Syu" ;;
    ID=endeavouros*) print_message "eos-update" ;;
    ID=centos*) print_message "yum update" ;;
    ID=rocky*) print_message "yum update" ;;
    ID=alma*) print_message "dnf upgrade" ;;
    ID=oracle*) print_message "yum update" ;;
    ID=aws*) print_message "yum update" ;;
    ID=raspbian*) print_message "apt upgrade" ;;
    ID=pop*) print_message "apt upgrade" ;;
    ID=linuxmint*) print_message "apt upgrade" ;;
    ID=mx*) print_message "apt upgrade" ;;
    ID=elementary*) print_message "apt upgrade" ;;
    ID=opensuse-leap*|ID=opensuse-tumbleweed*) print_message "zypper" ;;
    ID=slackware*) print_message "slackpkg" ;;
    ID=rhino*) print_message "nala upgrade" ;;

    *) echo "🐧 Unknown distro, but let's keep it cool! :) 🐧" ;;
esac

