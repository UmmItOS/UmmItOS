# UmmItOS

<a href="https://archlinux.org"><img height="64" src="https://img.shields.io/badge/Arch-1793D1?logo=arch-linux&logoColor=fff" alt="Arch Linux"></a>
<a href="https://hyprland.org"><img height="64" src="https://img.shields.io/badge/Hypr-1A1B26?logo=hyprland&logoColor=fff" alt="Hyprland"></a>

UmmItOS is an Arch Linux + Hyprland desktop, packaged as a terminal installer and a dotfiles bundle. Its desktop shell is written in QML on Quickshell: the bar, notifications, launcher, lock screen, settings and more, in English, written Cantonese and Taiwanese Mandarin.

**Latest release:** [v1.4.2](https://github.com/UmmItOS/UmmItOS/releases/tag/v1.4.2). Every version is on the [releases page](https://github.com/UmmItOS/UmmItOS/releases).

## Documentation

Everything you need to install, update and use UmmItOS is in this README. For the design, read [CLAUDE.md](./CLAUDE.md).

## Requirements

- A fresh or existing **Arch Linux** install with a normal user (not root).
- An **AMD** GPU. NVIDIA is not supported.
- `git` and `paru`. The installer fetches them if they are missing.

## Install

```sh
git clone --recursive https://github.com/UmmItOS/UmmItOS.git
cd UmmItOS
./install-menu.sh
```

`install-menu.sh` is the only installer. It shows a checklist: tick the steps you want (packages, GPU drivers, laptop extras, oh-my-zsh, dotfiles, login screen), run them in turn, then see how each one went. Reboot when it finishes.

Afterwards, `./post-install.sh --start-config` is an optional, per-user tuning pass (monitor mode and similar), to run inside the desktop.

## Update

- Click the **update** button in the bar, or press **Super+Shift+Return**. It opens the updater, which lists pacman, AUR, oh-my-zsh and flatpak updates, shows the latest Arch news, and reports how the run went.
- Or open **Settings → Update** to check for updates and to pull this repo.

## Using it

| Key | What it opens |
|---|---|
| Super+Return | Application launcher |
| Super+T | Terminal (kitty) |
| Super+E | File manager (yazi) |
| Super+/ | Keybind cheat sheet |
| Super+X | Session menu |
| Super+M | SAO menu |
| Super+D | Draw on the screen (lecture pen) |
| Super+F | Screenshot gallery |
| Super+B | Battery usage |
| Super+H | Health check |
| Super+P | Displays (single, duplicate or extend) |
| Alt+Tab | Window switcher |

Settings is the gear beside the power button in the bar. Right-click the empty desktop for a menu.

## Development

The shell lives in `configs/quickshell/`. Run it from the checkout, read its log, and check a change on screen without touching your live session:

```sh
qs -c ummitos ipc show            # every IPC target
qs log -c ummitos                 # the running shell's log
shellcheck install-menu.sh post-install.sh setup.sh install/*.sh lib/*.sh script/**/*.sh
```

[CLAUDE.md](./CLAUDE.md) describes how the installer and the shell fit together. [DOCS/CHECKLIST.md](./DOCS/CHECKLIST.md) lists what each change must pass, and [the release skill](./.claude/skills/release/SKILL.md) is the release procedure.

## Contributing

See the [contributing guidelines](./DOCS/CONTRIBUTING.md).

## Star me!

If you like these dotfiles, please leave a star — it keeps me motivated to maintain the repo I use every day. Thank you!

[![Star History Chart](https://app.repohistory.com/api/svg?repo=UmmItOS/UmmItOS&type=Date&background=0D1117&color=b562f8)](https://app.repohistory.com/star-history)

## License

GPLv3. See [LICENSE](./LICENSE).
