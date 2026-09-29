---
name: terminal-color
description: Color this terminal's backdrop with a named dark color from harness-tint and tell the user that color's name. Use when the user asks to pick a color, color or tint this terminal or tab, choose a backdrop, or asks which color this terminal is. Use when the user runs /terminal-color.
---

# Terminal color

When the user asks for a backdrop color, run one command and reply with the name it prints.

- The user named a color: `harness-tint use "<that name>"`.
- The user described one, such as something blue: `harness-tint list --free`, choose a matching id, then `harness-tint use <id>`.
- Otherwise: `harness-tint pick`.

The reply is one sentence using that name, such as "This terminal is Deep Cobalt." If the command fails, say that the terminal color did not change.

When the user asks which color this terminal is, run `harness-tint current` and answer with that name. When they ask which colors exist, run `harness-tint list`.

A later message keeps the color already chosen. Pick again only when the user asks for a new color.
