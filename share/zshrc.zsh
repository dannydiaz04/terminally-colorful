# Wrappers tint the current terminal, then run the real CLI.
# Install sources this file. HARNESS_TINT_DISABLE=1 skips the tint.

_ht_root="${HARNESS_TINT_ROOT:-$(cd "$(dirname -- "${(%):-%x}")/.." && pwd)}"
_ht_bin="${HARNESS_TINT_BIN:-$_ht_root/bin/harness-tint}"

claude() { command "$_ht_bin" wrap claude -- command claude "$@"; }
codex() { command "$_ht_bin" wrap codex -- command codex "$@"; }
grok() { command "$_ht_bin" wrap grok -- env GROK_TERMINAL_THEME=1 GROK_THEME=terminal command grok "$@"; }
agy() { command "$_ht_bin" wrap agy -- command agy "$@"; }
muse() { command "$_ht_bin" wrap muse -- command muse "$@"; }
prime-agent() { command "$_ht_bin" wrap prime -- command prime-agent "$@"; }
prime() { command "$_ht_bin" wrap prime -- command prime-agent "$@"; }
