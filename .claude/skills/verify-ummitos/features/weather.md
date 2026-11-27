# Weather card and the widget column

## What it is

The first card in the desktop widget column (top right, under the bar): the place, the temperature, today's range and the next hours from wttr.in. The column holds the weather, Now playing and DeepSeek cards, and closes up around whichever are hidden.

## Sub-features

- `weather-show`: with a place set, the card shows the place, the temperature, the condition with high and low, and five hourly slots. With no place, it is hidden.
- `weather-switch`: the right-click menu's "Weather card" switch sets `weather=` in `desktop.conf`.
- `column-collapse`: a hidden card leaves the column, so the cards under it move up into its place; a card that fades out slides the others up (`desktop/Widgets.qml`, `move` transition).
- `column-dodge`: the column steps below a notification toast at the top right.

## How to get to it (user POV)

- `qs -c ummitos ipc call weather setLocation "Hong Kong"` sets the place (an empty string turns it off); the right-click menu's "Weather card" switch hides it.

## Driving it with verify-ummitos

It needs network: the stack reaches wttr.in through the real `curl`.

Steps (proven 2026-11-27). Read each card's top and bottom by pixels down the column at x 1700 of a 1920×1080 shot (rows brighter than 4 against the empty desktop):

- **Weather.** `ipc.sh weather setLocation "Hong Kong"`, wait about 10 s: one card at the top shows "Hong Kong", a temperature and five slots.
- **Stack.** Start the fake player (`media.md`) and turn the DeepSeek card on (`deepseek.md`): three cards one under another with an even gap.
- **Collapse.** `ipc.sh weather setLocation ""`: the Now playing and DeepSeek cards move up into the weather card's place. Stop the player (`scripts/stop.sh python3`): the DeepSeek card moves up again.

## Gotchas

- The start-up health-check toast sits at the top right, and the column steps below it; dismiss it with `ipc.sh notifications clear` after it arrives, or count it as the first span.
- wttr.in can be slow or refuse; the card stays hidden until an answer arrives.
