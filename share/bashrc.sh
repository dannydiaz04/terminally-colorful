# Bash equivalent of share/zshrc.zsh.
_ht_root="${HARNESS_TINT_ROOT:-$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
_ht_bin="${HARNESS_TINT_BIN:-$_ht_root/bin/harness-tint}"

claude() { command "$_ht_bin" wrap claude -- command claude "$@"; }
codex() { command "$_ht_bin" wrap codex -- command codex "$@"; }
grok() { command "$_ht_bin" wrap grok -- env GROK_TERMINAL_THEME=1 GROK_THEME=terminal command grok "$@"; }
agy() { command "$_ht_bin" wrap agy -- command agy "$@"; }
muse() { command "$_ht_bin" wrap muse -- command muse "$@"; }
prime-agent() { command "$_ht_bin" wrap prime -- command prime-agent "$@"; }
prime() { command "$_ht_bin" wrap prime -- command prime-agent "$@"; }
