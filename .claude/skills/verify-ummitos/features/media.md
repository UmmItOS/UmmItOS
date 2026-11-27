# Now playing card

## What it is

A card in the desktop widget column (top right, under the weather card and above the DeepSeek card). It fades in only while the active MPRIS player is playing and the "Now playing card" switch is on, and shows the cover, "Now playing", the title, the artist, live bars and a progress line.

## Sub-features

- `media-show`: the card is visible only while a player is playing and `Settings.mediaShow` is on; otherwise it is at opacity 0 and the surface unmaps once every card has faded.
- `media-switch`: the right-click menu's "Now playing card" switch sets `media=` in `desktop.conf` and the card fades out and in.
- `media-title`: a title wider than its lane pauses, scrolls to its end, pauses and scrolls back, at 40 px/s, only while playing and visible.
- `media-fade`: a scrolling title fades at its edges instead of being cut. The left edge is crisp at rest and the right edge soft; at the far end the reverse; mid-scroll both are soft. A title that fits has no fade (`desktop/fade.frag`, applied as the title lane's `layer.effect`).
- `media-halo`: the cover's breathing halo reaches `Theme.media.haloScale` (1.2) and never touches the words.
- `media-artist`: the artist is dim and elided on the right, and hidden when empty.
- `media-progress`: a progress line shows only when the player reports a length.
- `media-controls`: with the pointer over the card, previous, pause and next replace the bars.
- `media-bars`: live bars from Cava. **Not provable in this stack**: there is no PipeWire, so they stay at their minimum.

## How to get to it (user POV)

- Play anything that shows up in an MPRIS player. The right-click menu's "Now playing card" switch hides it.

## Driving it with verify-ummitos

The stack has no player. Start the fake MPRIS player this skill ships, `scripts/fake-mpris.py` (`dbus-python`; it publishes `org.mpris.MediaPlayer2.fake` with `PlaybackStatus` Playing, a long title such as `[MV] 아일릿 (ILLIT) '체포하겠어 (Arrest Me)' Official Music Video`, the artist `HYBE LABELS`, a 200 s length, a 30 s position and no art):

```sh
. .claude/skills/verify-ummitos/scripts/env.sh
.claude/skills/verify-ummitos/scripts/run.sh python3 .claude/skills/verify-ummitos/scripts/fake-mpris.py &
```

Steps (proven 2026-11-27):

- **Appears.** After about 4 s `run.sh playerctl -l` lists `fake` and the card shows at the top right (crop `x 1550..1900, y 215..335` of a 1920×1080 shot): "Now playing", the placeholder cover, the artist, the dotted bars, a progress line at about 15 %.
- **Title scroll and fade.** Take `shot.sh` every 0.7 s for about 10 s. The title moves left and back. Measure the fade by pixels, not by eye: for one shot, take the brightest value of each column of the title row; across the 24 px at the lit end of the lane it falls to 0, and where the text is cut off it must not stop at full brightness. A hard cut means `desktop/fade.frag.qsb` did not load.
- **Switch.** Right-click the desktop, press `wtype -k Down` five times (the focus bar sits on "Now playing card"), then `wtype -k space`: `grep media= $STACK/home/.config/ummitos/desktop.conf` shows `media=0` and the card fades away.
- Kill the fake player with `run.sh pkill -f fake-mpris.py` (from a script file, not a command line that contains that text).

## Gotchas

- Hovering the card swaps the bars for the controls, so park the pointer away from it first (`hyprctl dispatch 'hl.dsp.cursor.move({ x = 960, y = 540 })'`).
- Qt 6.12.0's `MultiEffect` mask did nothing here, which is why the fade is a shader; see `.claude/rules/qml-traps.md`.
- The fake player cannot be controlled: `PlayPause` does nothing and next and previous are off.
