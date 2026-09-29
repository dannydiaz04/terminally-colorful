# harness-tint

Pick a named color for a terminal, then tell it apart from the others.

The catalog has 100 dark colors in [share/colors.tsv](share/colors.tsv). A skill, [skills/terminal-color/SKILL.md](skills/terminal-color/SKILL.md), tells the model to choose one when you ask, apply it, and say the name. Colors are not assigned by harness or model.

The window color is the backdrop. A full-screen harness paints its own background over that window, and it also sets the tab title itself, so harness-tint leaves the title alone. The color shows in the window before that harness takes over the screen and after it exits. Grok shows it for the whole session.

## Install

From a checkout of this repo:

```bash
./bin/harness-tint install
source ~/.zshrc
```

`install` symlinks `~/.local/bin/harness-tint`, sources the shell wrappers from `~/.zshrc`, and links the `terminal-color` skill into the user skill directories for Grok, Claude Code, Codex, agy, Prime, and Muse. It also removes automatic model tinting (Grok status line, Claude hooks, Codex hooks, agy status line) if an earlier version added it.

Open a new terminal after installing. The first time a color is applied, macOS asks for permission to let `osascript` control Terminal. Allow it.

Inside a harness, ask it to pick a color, or run `/terminal-color`. It applies one and tells you the name. Ask again when you want a different one.

`./bin/harness-tint doctor` shows the backend, the catalog, and which pieces are wired. `./bin/harness-tint uninstall` removes the wrappers and the skill links.

Bash can source [share/bashrc.sh](share/bashrc.sh) instead of the zsh file.

## What you see

Grok shows the color for the whole session. The `grok` wrapper sets `GROK_THEME=terminal` and `GROK_TERMINAL_THEME=1` for that process, and Grok's terminal theme leaves the window canvas visible. Your saved Grok theme is left as it is.

Prime often leaves the main canvas on the terminal background, so the window color shows through there too.

Claude Code, Codex, agy, and Muse paint their own full-screen backgrounds. The window color is there before they take over the screen and after they exit.

The shell wrappers do not choose a color. They remember the backdrop when a harness starts and restore it when that harness exits, including a harness started inside another one. A command the harness runs has no terminal of its own, so the color is applied to the terminal the harness was opened in. `HARNESS_TINT_DISABLE=1 claude` runs the real CLI and leaves the tab alone.

## Terminals

| Terminal | Backend |
| --- | --- |
| Terminal.app | AppleScript sets the tab background |
| iTerm2, Ghostty, kitty, WezTerm, Alacritty | OSC 11 sets the background |
| Anything else | The command still runs; the tab is unchanged |

`HARNESS_TINT_BACKEND=apple`, `osc`, or `dry` forces a backend. `dry` records colors in a log instead of drawing them, which is what the tests use.

## Commands

```text
harness-tint pick
harness-tint use "Deep Cobalt"
harness-tint list
harness-tint list --free
harness-tint current
harness-tint preview
harness-tint doctor
```

`pick` applies a color that is not already in use on another terminal and prints its name. `use` applies a specific id or name from the catalog. `list --free` hides colors that are already on a terminal.

## Tests

```bash
make test
```

The suite runs under `/bin/bash` so it stays compatible with the Bash 3.2 that ships with macOS. Regenerate the catalog with `python3 share/generate-colors.py`.
