# 🐾 PCCat

A desktop cat companion for macOS. PCCat lives on your screen — not in an app
window — as a floating, always-on-top panel. It naps, stretches, plays, and
meditates, keeping its own daily rhythm, played back from Furever Dock-style
**animated** illustrations.

## What it does

- **Animated cat art** — the cat is a set of looping WebP animations
  (idle, morning stretch, play, meditating, sleep) plus a flowers loop,
  played frame-by-frame with each file's real per-frame timing.
- **Daily rhythm** — wakes up and stretches around 9:00, offers to help at
  10:30, wants to play at 2:30, nags you to stretch and hydrate at 4:30,
  and is fast asleep by 9:30 pm.
- **Quick actions** — hover the cat: feed, water, meditate, play, nap, pet.
- **Speech bubbles** — the cat murmurs ambient lines, reacts to tricks, and
  announces reminders.
- **Reminders** — schedule anything; the cat pops a bubble (and a sound)
  when it fires.
- **Floating panel** — drag it anywhere, it stays above every window and
  shows on all desktops; its position is remembered.

## Getting started

Requires **macOS 14+** and only the **Command Line Tools**
(`xcode-select --install`). No Xcode project — plain Swift Package Manager.

```bash
# clone
git clone https://github.com/itxRishabh/mac-cat.git
cd mac-cat

# build and launch
./build.sh
open dist/PCCat.app
```

### The illustration files

The cat animations live in `local/illustrations/` (gitignored — not shipped
in this repo):

```
local/illustrations/
├── hero-cat.webp      idle / lying down
├── morning-cat.webp   stretch
├── play-cat.webp      play
├── break-cat.webp     meditating
├── sleep-cat.webp     nap
└── flowers.gif        flowers loop
```

`build.sh` copies them into `dist/PCCat.app/Contents/Resources/illustrations/`,
and the app also looks in `local/illustrations/` next to the repo. Drop your
own files in either place with the same names to change the look.

## Repository layout

```
Package.swift            SwiftPM manifest (executable target, macOS 14+)
build.sh                 builds release + assembles dist/PCCat.app
Sources/PCCat/
  PCCatApp.swift         app entry point, AppDelegate, status-bar item
  PetPanel.swift         transparent floating NSPanel (drag, all-spaces)
  PetOverlayView.swift   cat canvas, speech bubble, quick actions
  Illustrations.swift    animated WebP/GIF player (ImageIO frame decoder)
  PetBrain.swift         activities, daily routine, ambient chatter
  Store.swift            observable state, reminders, persistence
  SettingsView.swift     settings window (name, art status, routine, reminders)
  Models.swift           activities, settings, types
```

## License

MIT — see [LICENSE](LICENSE).
