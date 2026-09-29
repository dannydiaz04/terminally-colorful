#!/bin/bash
# Exercises color math, model detection, nested restore, and install.
set -eu

ROOT="$(cd "$(dirname -- "$0")/.." && pwd)"
HT=(/bin/bash "$ROOT/bin/harness-tint")
failures=0

pass() { printf 'ok  %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; failures=$((failures + 1)); }

expect_eq() {
  local name="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then
    pass "$name"
  else
    fail "$name (want $want, got $got)"
  fi
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

export HARNESS_TINT_BACKEND=dry
export HARNESS_TINT_TTY=/dev/ttys-test
export HARNESS_TINT_STATE_DIR="$tmpdir/state"
export HARNESS_TINT_DRY_LOG="$tmpdir/dry.log"
export HARNESS_TINT_HOME="$tmpdir/home"
export HARNESS_TINT_ZSHRC="$tmpdir/home/.zshrc"
export HARNESS_TINT_CODEX_CONFIG="$tmpdir/home/.codex/config.toml"
export HARNESS_TINT_CODEX_HOOKS="$tmpdir/home/.codex/hooks.json"
export HARNESS_TINT_CLAUDE_SETTINGS="$tmpdir/home/.claude/settings.json"
export HARNESS_TINT_GROK_CONFIG="$tmpdir/home/.grok/config.toml"
export HARNESS_TINT_AGY_SETTINGS="$tmpdir/home/.gemini/antigravity-cli/settings.json"
export HARNESS_TINT_MUSE_SETTINGS="$tmpdir/home/.config/muse/settings.json"
export HARNESS_TINT_PRIME_SETTINGS="$tmpdir/home/.prime/agent/settings.json"
unset HARNESS_TINT_MODEL || true

mkdir -p "$tmpdir/home/.codex" "$tmpdir/home/.claude" "$tmpdir/home/.grok" \
  "$tmpdir/home/.gemini/antigravity-cli" "$tmpdir/home/.config/muse" \
  "$tmpdir/home/.prime/agent"

cat >"$HARNESS_TINT_CODEX_CONFIG" <<'EOF'
model = "gpt-6-astra"

[tui]
model = "inside-table"
EOF

cat >"$HARNESS_TINT_CLAUDE_SETTINGS" <<'EOF'
{
  "model": "sonnet",
  "theme": "dark"
}
EOF

cat >"$HARNESS_TINT_GROK_CONFIG" <<'EOF'
[ui]
compact_mode = false

[models]
default = "grok-4.7"
EOF

cat >"$HARNESS_TINT_AGY_SETTINGS" <<'EOF'
{
  "colorScheme": "dark",
  "model": "Gemini 3.8 Flash (High)"
}
EOF

printf '%s\n' '{"provider":"meta","model":"muse-spark-1.3-contributor"}' \
  >"$HARNESS_TINT_MUSE_SETTINGS"
printf '%s\n' '{"defaultProvider":"openai-codex","defaultModel":"gpt-6-astra"}' \
  >"$HARNESS_TINT_PRIME_SETTINGS"

codex_astra="$("${HT[@]}" color codex gpt-6-astra)"
codex_luna="$("${HT[@]}" color codex gpt-6-luna)"
prime_astra="$("${HT[@]}" color prime gpt-6-astra)"
claude_sonnet="$("${HT[@]}" color claude sonnet)"
claude_haiku="$("${HT[@]}" color claude haiku)"
claude_opus="$("${HT[@]}" color claude opus)"
grok_47="$("${HT[@]}" color grok grok-4.7)"
agy_flash="$("${HT[@]}" color agy "Gemini 3.8 Flash (High)")"
prime_gemma="$("${HT[@]}" color prime llama/gemma-4-31b)"

expect_eq "codex astra slot 0" "#122448" "$codex_astra"
expect_eq "codex luna slot 4" "#264c99" "$codex_luna"
expect_eq "sol revisions share a shade" "$("${HT[@]}" color codex gpt-6-sol)" "$("${HT[@]}" color codex gpt-6.1-sol)"
expect_eq "claude sonnet differs from haiku" "different" \
  "$([ "$claude_sonnet" != "$claude_haiku" ] && printf different || printf same)"
expect_eq "same model name, different harness" "different" \
  "$([ "$codex_astra" != "$prime_astra" ] && printf different || printf same)"
expect_eq "provider prefix uses the pinned model" "$("${HT[@]}" color prime gemma-4-31b)" "$prime_gemma"

again="$("${HT[@]}" color codex some-unknown-model)"
expect_eq "unknown model is stable" "$again" "$("${HT[@]}" color codex some-unknown-model)"

palette="$("${HT[@]}" palette)"
python3 -c '
import sys
def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def lum(h):
    r = int(h[1:3], 16); g = int(h[3:5], 16); b = int(h[5:7], 16)
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
bad = []
for line in sys.stdin.read().splitlines()[1:]:
    hex_color = line.split()[-1]
    if lum(hex_color) >= 0.18:
        bad.append(line.strip())
if bad:
    sys.stderr.write("\n".join(bad) + "\n")
    sys.exit(1)
' <<<"$palette" && pass "palette stays dark" || fail "palette stays dark"

reset_log() { : >"$HARNESS_TINT_DRY_LOG"; rm -rf "$HARNESS_TINT_STATE_DIR"; }

run_wrap() {
  reset_log
  set +e
  "${HT[@]}" "$@"
  status=$?
  set -e
  printf '%s' "$status"
}

status="$(run_wrap wrap claude -- true --model haiku)"
expect_eq "wrap true exits 0" "0" "$status"
grep -q "set $claude_haiku" "$HARNESS_TINT_DRY_LOG" && pass "wrap uses the flag model" || fail "wrap uses the flag model"
grep -q "^reset " "$HARNESS_TINT_DRY_LOG" && pass "wrap restores on exit" || fail "wrap restores on exit"
[ ! -d "$HARNESS_TINT_STATE_DIR/_dev_ttys-test" ] && pass "state removed after restore" || fail "state removed after restore"

status="$(run_wrap wrap claude -- false --model sonnet)"
expect_eq "wrap keeps the command status" "1" "$status"
grep -q "^reset " "$HARNESS_TINT_DRY_LOG" && pass "failed command still restores" || fail "failed command still restores"

reset_log
HARNESS_TINT_DISABLE=1 "${HT[@]}" wrap claude -- true --model sonnet
if [ ! -s "$HARNESS_TINT_DRY_LOG" ]; then
  pass "disable skips the tint"
else
  fail "disable skips the tint"
fi

reset_log
HARNESS_TINT_MODEL=sonnet "${HT[@]}" wrap claude -- \
  env -u HARNESS_TINT_MODEL "${HT[@]}" wrap prime -- true --provider llama --model gemma-4-31b
unset HARNESS_TINT_MODEL
log="$(cat "$HARNESS_TINT_DRY_LOG")"
line1="$(printf '%s\n' "$log" | sed -n '1p')"
line2="$(printf '%s\n' "$log" | sed -n '2p')"
line3="$(printf '%s\n' "$log" | sed -n '3p')"
line4="$(printf '%s\n' "$log" | sed -n '4p')"
expect_eq "outer tint" "set $claude_sonnet claude · sonnet" "$line1"
expect_eq "inner tint" "set $prime_gemma prime · llama/gemma-4-31b" "$line2"
expect_eq "inner restore returns to outer" "set $claude_sonnet claude · sonnet" "$line3"
case "$line4" in
  reset*) pass "outer restore clears the tab" ;;
  *) fail "outer restore clears the tab ($line4)" ;;
esac

reset_log
HARNESS_TINT_MODEL=sonnet "${HT[@]}" wrap claude -- \
  env -u HARNESS_TINT_MODEL /bin/bash -c "printf '%s' '{\"to_model\":\"opus\"}' | /bin/bash '$ROOT/bin/harness-tint' on-event claude"
unset HARNESS_TINT_MODEL
log="$(cat "$HARNESS_TINT_DRY_LOG")"
printf '%s\n' "$log" | grep -q "set $claude_opus" && pass "model switch retints" || fail "model switch retints"
printf '%s\n' "$log" | grep -q "^reset " && pass "model switch still restores" || fail "model switch still restores"

reset_log
HARNESS_TINT_MODEL=haiku "${HT[@]}" wrap claude -- \
  env -u HARNESS_TINT_MODEL /bin/bash -c "printf '%s' '{}' | /bin/bash '$ROOT/bin/harness-tint' on-event claude"
unset HARNESS_TINT_MODEL
if grep -q "set $claude_sonnet" "$HARNESS_TINT_DRY_LOG"; then
  fail "empty hook keeps the launch model"
else
  pass "empty hook keeps the launch model"
fi

reset_log
printf '%s' '{"model":{"id":"grok-4.6","display_name":"Grok 4.6"}}' | "${HT[@]}" on-statusline grok
grep -q "set $("${HT[@]}" color grok grok-4.6)" "$HARNESS_TINT_DRY_LOG" \
  && pass "grok status payload retints" || fail "grok status payload retints"
out="$(printf '%s' '{"model":{"display_name":"Gemini 3.8 Flash (High)"}}' | "${HT[@]}" on-statusline agy)"
expect_eq "agy status line prints the model" "Gemini 3.8 Flash (High)" "$out"

# Config detection, including a model key that appears only inside a later table.
reset_log
"${HT[@]}" wrap codex -- true
grep -q "set $codex_astra " "$HARNESS_TINT_DRY_LOG" && pass "codex config model" || fail "codex config model"

reset_log
"${HT[@]}" wrap codex -- true -m gpt-6-luna
grep -q "set $codex_luna " "$HARNESS_TINT_DRY_LOG" && pass "codex -m wins" || fail "codex -m wins"

reset_log
"${HT[@]}" wrap codex -- true -c 'model="gpt-6-luna"'
grep -q "set $codex_luna " "$HARNESS_TINT_DRY_LOG" && pass "codex -c model wins" || fail "codex -c model wins"

reset_log
"${HT[@]}" wrap grok -- true
grep -q "set $grok_47 " "$HARNESS_TINT_DRY_LOG" && pass "grok config model" || fail "grok config model"

reset_log
"${HT[@]}" wrap agy -- true
grep -q "set $agy_flash " "$HARNESS_TINT_DRY_LOG" && pass "agy config model" || fail "agy config model"

reset_log
"${HT[@]}" wrap prime -- true
grep -q "set $prime_astra " "$HARNESS_TINT_DRY_LOG" && pass "prime provider and model" || fail "prime provider and model"

# Install and uninstall against the temp home, twice.
"${HT[@]}" install >/dev/null
grep -q "share/zshrc.zsh" "$HARNESS_TINT_ZSHRC" && pass "zshrc wired" || fail "zshrc wired"
grep -q "on-statusline grok" "$HARNESS_TINT_GROK_CONFIG" && pass "grok status line wired" || fail "grok status line wired"
grep -q "on-event claude" "$HARNESS_TINT_CLAUDE_SETTINGS" && pass "claude hook wired" || fail "claude hook wired"
grep -q "on-event codex" "$HARNESS_TINT_CODEX_HOOKS" && pass "codex hook wired" || fail "codex hook wired"
grep -q "on-statusline agy" "$HARNESS_TINT_AGY_SETTINGS" && pass "agy status line wired" || fail "agy status line wired"
python3 - "$HARNESS_TINT_CLAUDE_SETTINGS" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data["model"] == "sonnet"
assert data["theme"] == "dark"
assert "SessionStart" in data["hooks"]
assert "PostModelSwitch" in data["hooks"]
PY
pass "claude settings keep existing keys"

"${HT[@]}" install >/dev/null
count="$(grep -c ">>> harness-tint >>>" "$HARNESS_TINT_ZSHRC")"
expect_eq "install is idempotent" "1" "$count"
hooks="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(sum(1 for g in d["hooks"]["PostModelSwitch"] for h in g["hooks"]))' "$HARNESS_TINT_CLAUDE_SETTINGS")"
expect_eq "claude hook is not duplicated" "1" "$hooks"

# A custom agy status line is left alone.
custom="$tmpdir/custom-agy.json"
printf '%s\n' '{"statusLine":{"type":"command","command":"my-status"},"model":"Gemini 3.8 Flash (High)"}' >"$custom"
HARNESS_TINT_AGY_SETTINGS="$custom" "${HT[@]}" install >/dev/null
grep -q "my-status" "$custom" && pass "custom agy status line is kept" || fail "custom agy status line is kept"
grep -q "harness-tint" "$custom" && fail "custom agy status line was replaced" || pass "custom agy status line was not replaced"

"${HT[@]}" uninstall >/dev/null
if grep -q "harness-tint" "$HARNESS_TINT_ZSHRC" "$HARNESS_TINT_GROK_CONFIG" "$HARNESS_TINT_CLAUDE_SETTINGS" "$HARNESS_TINT_CODEX_HOOKS" "$HARNESS_TINT_AGY_SETTINGS"; then
  fail "uninstall removes wiring"
else
  pass "uninstall removes wiring"
fi
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["model"]=="sonnet" and "hooks" not in d' "$HARNESS_TINT_CLAUDE_SETTINGS"
pass "uninstall keeps the claude model"

if [ "$failures" -eq 0 ]; then
  printf 'all tests passed\n'
else
  printf '%s failed\n' "$failures" >&2
  exit 1
fi
