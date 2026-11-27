# QR scanner

Super+Shift+Q, or the bar's scan button, photographs the screen and finds every code on it with `zbarimg`. It then labels each code and shows a detail panel: kind, scheme, host, path and raw content. Open (labelled Write, Call or Map for mail, phone and map codes) sends the code to `xdg-open`, Copy copies the content, and a Wi-Fi code joins the network.

## Sub-features

- `scan-find`: every code on the screen gets a chip with its title.
- `scan-detail`: the panel shows the selected code's fields. For a web link the Host is the host the browser will open (the backslash case is fixed in v1.2.1).
- `scan-act`: Open, Copy and Wi-Fi join; a plain text code gets only Copy. **Do not drive Open**, because it launches the user's browser.
- `scan-failed`: when grim or zbar fails, a "Scan failed" toast from "QR scanner" shows (source only, not driven).
- `scan-none`: with no code on screen, a "No QR code on screen" toast from "QR scanner" appears and no overlay opens (seen 2026-11-25).
- `scan-reread`: a code with non-ASCII content (zbar's XML mangles it) is read again per region, and each region comes back as one base64 line, so a code holding odd bytes such as 0x1E cannot shift data onto the next code.

## How to get to it (user POV)

- Super+Shift+Q, or the scan button in the bar's tool cluster. Super+Shift+Q calls `scan toggle`; the bar button calls `Scan.start` for its own screen, so it has no IPC form.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- No other window is on screen: close kitty and the like first.
- `qrencode` and `mpv` are installed.

Steps (proven 2026-11-01):

- **Show a code.** Run `. .claude/skills/verify-ummitos/scripts/env.sh; qrencode -s 12 -o "$STACK/home/qr.png" 'https://evil.example\@bank.example/login'`, then start mpv in the background: `( in_stack setsid mpv --no-config --image-display-duration=inf --force-window=yes --title=qr "$STACK/home/qr.png" >/dev/null 2>&1 & )`. Wait 2.5 s.
- **Scan.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh scan toggle`, wait 3 s, then `.claude/skills/verify-ummitos/scripts/shot.sh scan-result`. Expect the chip `evil.example` and the panel "Web link" with Host `evil.example`, Path `/@bank.example/login` (a browser reads the `\` as `/`) and the raw content `https://evil.example\@bank.example/login`. The layer is `ummitos-scan`.
- **Close.** Run `.claude/skills/verify-ummitos/scripts/run.sh wtype -k Escape`, or `.claude/skills/verify-ummitos/scripts/ipc.sh scan close`. Stop mpv with `.claude/skills/verify-ummitos/scripts/stop.sh mpv`. `down.sh` also catches it.

- **Re-read path** (proven 2026-11-18). Put a UTF-8 code next to the link: `printf '香港 UmmItOS' | qrencode -8 -s 10 -o "$STACK/home/qr1.png"`, compose both onto one 1920x1080 picture with `magick` (`-geometry +300+300` and `+1200+300`), and show it full screen with `run.sh sh -c "mpv --no-config --fs --image-display-duration=inf --osc=no <picture> >/dev/null 2>&1 &"`. After `scan toggle`, one chip reads `香港 UmmItOS` and the other `evil.example`. To prove the old separator bug is gone, make the UTF-8 code `中文` + byte 0x1E + a URL: its chip must show the whole content, not just `中文`.

## Gotchas

- Another window on screen squeezed the mpv window, and the scan reported "No QR code on screen". Keep the screen to the code alone.
- Copy and Wi-Fi join touch the clipboard and NetworkManager. Neither is isolated (NetworkManager is on the system bus), so do not drive them.
