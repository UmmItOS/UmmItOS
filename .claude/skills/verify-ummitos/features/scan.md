# QR scanner

Super+Shift+Q, or the bar's scan button, photographs the screen and finds every code on it with `zbarimg`. It then labels each code and shows a detail panel: kind, scheme, host, path and raw content. Open sends a web link to `xdg-open`, Copy copies the content, and a Wi-Fi code joins the network.

## Sub-features

- `scan-find`: every code on the screen gets a chip with its title.
- `scan-detail`: the panel shows the selected code's fields. For a web link the Host is the host the browser will open (the backslash case is fixed in v1.2.1).
- `scan-act`: Open, Copy and Wi-Fi join. **Do not drive Open**, because it launches the user's browser.
- `scan-none`: with no code on screen, a "No QR code on screen" notice appears.

## How to get to it (user POV)

- Super+Shift+Q, or the scan button in the bar's tool cluster. Both call `scan toggle`.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- No other window is on screen: close kitty and the like first.
- `qrencode` and `mpv` are installed.

Steps (proven 2026-10-29):

- **Show a code.** Run `. .claude/skills/verify-ummitos/scripts/env.sh; qrencode -s 12 -o "$STACK/home/qr.png" 'https://evil.example\@bank.example/login'`, then start mpv in the background: `( in_stack setsid mpv --no-config --image-display-duration=inf --force-window=yes --title=qr "$STACK/home/qr.png" >/dev/null 2>&1 & )`. Wait 2.5 s.
- **Scan.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh scan toggle`, wait 3 s, then `.claude/skills/verify-ummitos/scripts/shot.sh scan-result`. Expect the chip `evil.example` and the panel "Web link" with Host `evil.example`, Path `\@bank.example/login` and the raw content. The layer is `ummitos-scan`.
- **Close.** Run `.claude/skills/verify-ummitos/scripts/run.sh wtype -k Escape`. Stop mpv by its environment: `for p in /proc/[0-9]*; do tr '\0' '\n' 2>/dev/null < $p/environ | grep -qx "XDG_RUNTIME_DIR=$STACK/run" && [ "$(cat $p/comm)" = mpv ] && kill ${p#/proc/}; done`. `down.sh` also catches it.

## Gotchas

- Another window on screen squeezed the mpv window, and the scan reported "No QR code on screen". Keep the screen to the code alone.
- Copy and Wi-Fi join touch the clipboard and NetworkManager. Neither is isolated (NetworkManager is on the system bus), so do not drive them.
