# UmmItOS

<a href="https://archlinux.org"><img height="64" src="https://img.shields.io/badge/Arch-1793D1?logo=arch-linux&logoColor=fff" alt="Arch Linux"></a>
<a href="https://hyprland.org"><img height="64" src="https://img.shields.io/badge/Hypr-1A1B26?logo=hyprland&logoColor=fff" alt="Hyprland"></a>

An Arch Linux + Hyprland desktop, packaged as an installer and dotfiles bundle.

The installer adds the packages and a greetd login screen, then copies the configs. The desktop itself is one Quickshell app in `configs/quickshell/`. It replaces waybar, swaync, rofi, wlogout, swww, hyprshot and hyprlock with:

- **Bar.** Workspaces, tray, bandwidth, Wi-Fi, Bluetooth and volume, each with hover tips.
- **Notifications.** Toasts and a history panel.
- **Lock screen.** Weather and now-playing cards. A second wrong password starts an intruder alarm.
- **Overlays.**
  - App launcher and clipboard manager.
  - Alt+Tab switcher and a hot-corner overview.
  - Screenshot tool and a searchable screenshot gallery.
  - Screen recorder.
  - QR scanner.
  - Picture converter.
- **Settings and maintenance.** A settings panel, a health check (Super+H), and an updater that shows the Arch news.

Super+/ lists every shortcut.

## Requirements

- Arch Linux. The installer refuses to run anywhere else.
- A normal user account. Do not run the installer as root.
- NVIDIA is not supported. The GPU packages are for AMD.

## Installation

Full instructions live on the official docs: **[docs.ummit.dev](https://docs.ummit.dev)**.

To install from a clone, work in a folder that only you can write, such as your home folder:

```sh
cd ~
git clone --recursive https://github.com/UmmItOS/UmmItOS.git
cd UmmItOS
./install-menu.sh
```

The `--recursive` flag also fetches the wallpaper and brand-image submodules. At your first login after the reboot, UmmItOS offers an optional tuning pass once: it can lock in the exact monitor mode and similar settings. To run that pass later, run `./post-install.sh --start-config` in the same folder.

To update later, open Settings → Update, or press Super+Shift+Return to run the updater. Releases are listed on the [releases page](https://github.com/UmmItOS/UmmItOS/releases).

## Star me!

If you like these dotfiles, please leave a star — it keeps me motivated to maintain the repo I use every day. Thank you!

[![Star History Chart](https://app.repohistory.com/api/svg?repo=UmmItOS/UmmItOS&type=Date&background=0D1117&color=b562f8)](https://app.repohistory.com/star-history)

## Contributing

See the [contributing guidelines](./DOCS/CONTRIBUTING.md). [CLAUDE.md](./CLAUDE.md) describes how the installer and the shell fit together, and [DOCS/CHECKLIST.md](./DOCS/CHECKLIST.md) lists what each change must pass.

## License

GPLv3. See [LICENSE](./LICENSE).
