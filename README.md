# harness-tint

Color the terminal tab for the coding harness you are in, and use a lighter or darker shade of that same hue for the model.

| Harness | Hue |
| --- | --- |
| Codex | blue |
| Claude Code | amber |
| Grok Build | magenta |
| agy | green |
| Muse | violet |
| Prime | teal |

Pinned models get a fixed shade. Any other model name hashes to one of five shades in that harness, so the color stays put across launches. Edit [share/palette.tsv](share/palette.tsv) to change a hue or pin a model.

The window color is the backdrop. A full-screen harness paints its own background over that window, and it also sets the tab title itself, so harness-tint leaves the title alone.

## Install

From a checkout of this repo:

```bash
./bin/harness-tint install
source ~/.zshrc
```

`install` does five things:

- Symlinks `~/.local/bin/harness-tint`
- Sources the wrappers from `~/.zshrc`
- Points Grok's status line at a silent retint command
- Adds Claude Code `SessionStart` and `PostModelSwitch` hooks
- Adds Codex `SessionStart` and `UserPromptSubmit` hooks
- Adds an agy status line when that file does not already have one

Open a new terminal after installing. The first time the tint runs, macOS asks for permission to let `osascript` control Terminal. Allow it.

Inside Codex, run `/hooks` once and trust the harness-tint hook. Codex skips a new hook until you do.

`./bin/harness-tint doctor` shows the backend, the model each harness has saved, and which pieces are wired. `./bin/harness-tint uninstall` removes the wrappers and the hooks this tool added.

Bash can source [share/bashrc.sh](share/bashrc.sh) instead of the zsh file.

## What you see

Grok shows the tint for the whole session. The `grok` wrapper sets `GROK_THEME=terminal` and `GROK_TERMINAL_THEME=1` for that process, and Grok's terminal theme leaves the window canvas visible. A model change, including `/model`, retints through the status line. Your saved Grok theme is left as it is; the terminal theme applies only to `grok` launched from the wrapper.

Prime often leaves the main canvas on the terminal background, so the window color shows through there too. Launch flags `--provider` and `--model` are part of the color, so `llama/gemma-4-31b` is a different shade from `openai-codex/gpt-6-astra`.

Claude Code, Codex, agy, and Muse paint their own full-screen backgrounds. The window color is there before they take over the screen and after they exit. Claude retints when the session starts and when you switch models. Codex retints on session start and on the next prompt after a model change. agy retints when its status line runs. Muse and Prime pick up the model at launch.

`HARNESS_TINT_DISABLE=1 claude` runs the real CLI and leaves the tab alone.

## Terminals

| Terminal | Backend |
| --- | --- |
| Terminal.app | AppleScript sets the tab background |
| iTerm2, Ghostty, kitty, WezTerm, Alacritty | OSC 11 sets the background |
| Anything else | The command still runs; the tab is unchanged |

`HARNESS_TINT_BACKEND=apple`, `osc`, or `dry` forces a backend. `dry` records colors in a log instead of drawing them, which is what the tests use.

## Commands

```text
harness-tint preview
harness-tint color codex gpt-6-luna
harness-tint apply claude sonnet
harness-tint restore
harness-tint doctor
```

Shell wrappers call `wrap`, which tints, runs the real binary, and restores the previous color on exit. A Prime session started inside a Claude session restores the Claude color when Prime exits, then the original terminal color when Claude exits.

## Tests

```bash
make test
```

The suite runs under `/bin/bash` so it stays compatible with the Bash 3.2 that ships with macOS.
