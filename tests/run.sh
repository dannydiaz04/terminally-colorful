#!/bin/bash
# Catalog, pick/use, nested restore, and install.
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

field() {
  awk -F '\t' -v key="$1" '$1 == key { print $3; exit }' "$ROOT/share/colors.tsv"
}

name_of() {
  awk -F '\t' -v key="$1" '$1 == key { print $2; exit }' "$ROOT/share/colors.tsv"
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

export HARNESS_TINT_BACKEND=dry
export HARNESS_TINT_TTY=/dev/ttys-test
export HARNESS_TINT_STATE_DIR="$tmpdir/state"
export HARNESS_TINT_DRY_LOG="$tmpdir/dry.log"
export HARNESS_TINT_HOME="$tmpdir/home"
export HARNESS_TINT_ZSHRC="$tmpdir/home/.zshrc"
export HARNESS_TINT_CODEX_HOOKS="$tmpdir/home/.codex/hooks.json"
export HARNESS_TINT_CLAUDE_SETTINGS="$tmpdir/home/.claude/settings.json"
export HARNESS_TINT_GROK_CONFIG="$tmpdir/home/.grok/config.toml"
export HARNESS_TINT_AGY_SETTINGS="$tmpdir/home/.gemini/antigravity-cli/settings.json"
unset HARNESS_TINT_MODEL || true

mkdir -p "$tmpdir/home/.codex" "$tmpdir/home/.claude" "$tmpdir/home/.grok" \
  "$tmpdir/home/.gemini/antigravity-cli" "$tmpdir/home/.config/muse" \
  "$tmpdir/home/.prime/agent"

python3 - "$ROOT/share/colors.tsv" <<'PY'
import math, sys
path = sys.argv[1]
rows = []
for line in open(path, encoding="utf-8"):
    line = line.rstrip("\n")
    if not line or line.startswith("#"):
        continue
    cid, name, hx = line.split("\t")
    rows.append((cid, name, hx))

def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def lum(h):
    r, g, b = int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)

def lab(h):
    def f(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = f(int(h[1:3], 16)), f(int(h[3:5], 16)), f(int(h[5:7], 16))
    x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
    y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
    z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041
    def ff(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = ff(x / 0.95047), ff(y), ff(z / 1.08883)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))

def de(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))

if len(rows) != 100:
    sys.exit("count %d" % len(rows))
ids = [r[0] for r in rows]
names = [r[1] for r in rows]
hexes = [r[2] for r in rows]
if len(set(ids)) != 100 or len(set(names)) != 100 or len(set(hexes)) != 100:
    sys.exit("duplicates")
labs = []
for cid, name, hx in rows:
    y = lum(hx)
    if y <= 0.02 or y >= 0.18:
        sys.exit("%s luminance %.3f" % (cid, y))
    labs.append(lab(hx))
closest = min(de(labs[i], labs[j]) for i in range(len(labs)) for j in range(i + 1, len(labs)))
if closest < 4:
    sys.exit("closest %.2f" % closest)
print("closest %.2f" % closest)
PY
pass "catalog is 100 distinct dark colors"

list_count="$("${HT[@]}" list | wc -l | tr -d ' ')"
expect_eq "list prints the catalog" "100" "$list_count"

cobalt_hex="$(field cobalt)"
forest_hex="$(field forest)"
deep_name="$(name_of cobalt-deep)"
deep_hex="$(field cobalt-deep)"

reset_log() { : >"$HARNESS_TINT_DRY_LOG"; rm -rf "$HARNESS_TINT_STATE_DIR"; }

reset_log
got="$("${HT[@]}" use "Deep Cobalt")"
expect_eq "use accepts the display name" "$deep_name" "$got"
got="$("${HT[@]}" use cobalt-deep)"
expect_eq "use accepts the id" "$deep_name" "$got"
grep -q "set $deep_hex Deep Cobalt" "$HARNESS_TINT_DRY_LOG" && pass "use paints the hex" || fail "use paints the hex"
expect_eq "current reports the color" "$deep_name" "$("${HT[@]}" current)"
if "${HT[@]}" list --free | awk -F '\t' -v hex="$deep_hex" '$3 == hex { found = 1 } END { exit found ? 0 : 1 }'; then
  fail "free list hides the color in use"
else
  pass "free list hides the color in use"
fi

reset_log
set +e
"${HT[@]}" use "not a color" >/dev/null 2>&1
status=$?
set -e
expect_eq "unknown color fails" "1" "$status"
if [ -s "$HARNESS_TINT_DRY_LOG" ]; then
  fail "unknown color does not paint"
else
  pass "unknown color does not paint"
fi
expect_eq "current is none before a pick" "none" "$("${HT[@]}" current)"

got="$(HARNESS_TINT_TTY=/dev/tty "${HT[@]}" doctor | awk '/^tty: / { print; exit }')"
if [ "$got" = "tty: /dev/tty" ]; then
  fail "a bare /dev/tty is not a terminal tab"
else
  pass "a bare /dev/tty is not a terminal tab"
fi

reset_log
first="$("${HT[@]}" list --free | awk -F '\t' 'NR == 1 { print $2; exit }')"
got="$("${HT[@]}" pick)"
expect_eq "pick uses the first free color" "$first" "$got"
second="$("${HT[@]}" pick)"
if [ "$first" = "$second" ]; then
  fail "second pick is a different color"
else
  pass "second pick is a different color"
fi
expect_eq "current follows the latest pick" "$second" "$("${HT[@]}" current)"
second_hex="$(awk -F '\t' -v name="$second" '$2 == name { print $3; exit }' "$ROOT/share/colors.tsv")"
if HARNESS_TINT_TTY=/dev/ttys-other "${HT[@]}" list --free | awk -F '\t' -v hex="$second_hex" '$3 == hex { found = 1 } END { exit(found ? 0 : 1) }'; then
  fail "other terminal hides the active color"
else
  pass "other terminal hides the active color"
fi

reset_log
status=0
set +e
"${HT[@]}" wrap claude -- true
status=$?
set -e
expect_eq "wrap true exits 0" "0" "$status"
if [ -s "$HARNESS_TINT_DRY_LOG" ]; then
  fail "wrap does not paint on its own"
else
  pass "wrap does not paint on its own"
fi
[ ! -d "$HARNESS_TINT_STATE_DIR/_dev_ttys-test" ] && pass "state removed after wrap" || fail "state removed after wrap"

reset_log
set +e
"${HT[@]}" wrap claude -- false
status=$?
set -e
expect_eq "wrap keeps the command status" "1" "$status"

reset_log
HARNESS_TINT_DISABLE=1 "${HT[@]}" wrap claude -- true
if [ ! -s "$HARNESS_TINT_DRY_LOG" ]; then
  pass "disable skips the bookkeeping"
else
  fail "disable skips the bookkeeping"
fi

reset_log
"${HT[@]}" wrap claude -- true --help
if [ -s "$HARNESS_TINT_DRY_LOG" ]; then
  fail "help skips the bookkeeping"
else
  pass "help skips the bookkeeping"
fi

reset_log
set +e
"${HT[@]}" wrap claude -- /bin/bash "$ROOT/bin/harness-tint" use cobalt
status=$?
set -e
expect_eq "use inside wrap exits 0" "0" "$status"
log="$(cat "$HARNESS_TINT_DRY_LOG")"
line1="$(printf '%s\n' "$log" | sed -n '1p')"
line2="$(printf '%s\n' "$log" | sed -n '2p')"
expect_eq "wrap paints the chosen color" "set $cobalt_hex Cobalt" "$line1"
case "$line2" in
  reset*) pass "wrap restores after the chosen color" ;;
  *) fail "wrap restores after the chosen color ($line2)" ;;
esac
[ ! -d "$HARNESS_TINT_STATE_DIR/_dev_ttys-test" ] && pass "state removed after restore" || fail "state removed after restore"

reset_log
export HT_SCRIPT="$ROOT/bin/harness-tint"
"${HT[@]}" wrap claude -- /bin/bash -c '
  /bin/bash "$HT_SCRIPT" use cobalt
  /bin/bash "$HT_SCRIPT" wrap prime -- /bin/bash "$HT_SCRIPT" use forest
'
log="$(cat "$HARNESS_TINT_DRY_LOG")"
line1="$(printf '%s\n' "$log" | sed -n '1p')"
line2="$(printf '%s\n' "$log" | sed -n '2p')"
line3="$(printf '%s\n' "$log" | sed -n '3p')"
line4="$(printf '%s\n' "$log" | sed -n '4p')"
expect_eq "outer color" "set $cobalt_hex Cobalt" "$line1"
expect_eq "inner color" "set $forest_hex Forest" "$line2"
expect_eq "inner restore returns to outer" "set $cobalt_hex Cobalt" "$line3"
case "$line4" in
  reset*) pass "outer restore clears the tab" ;;
  *) fail "outer restore clears the tab ($line4)" ;;
esac

reset_log
printf '%s' '{"to_model":"opus"}' | "${HT[@]}" on-event claude
printf '%s' '{"model":{"display_name":"Gemini"}}' | "${HT[@]}" on-statusline agy >/dev/null
if [ -s "$HARNESS_TINT_DRY_LOG" ]; then
  fail "old model hooks do not paint"
else
  pass "old model hooks do not paint"
fi

# Install removes model hooks and links the skill. Existing settings stay.
cat >"$HARNESS_TINT_CLAUDE_SETTINGS" <<'EOF'
{
  "model": "sonnet",
  "theme": "dark",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {"type": "command", "command": "/tmp/harness-tint on-event claude", "timeout": 5},
          {"type": "command", "command": "other-hook", "timeout": 5}
        ]
      }
    ],
    "PostModelSwitch": [
      {
        "hooks": [
          {"type": "command", "command": "/tmp/harness-tint on-event claude", "timeout": 5}
        ]
      }
    ]
  }
}
EOF
cat >"$HARNESS_TINT_GROK_CONFIG" <<'EOF'
[models]
default = "grok-4.7"

# >>> harness-tint >>>
[ui.status_line]
type = "command"
command = "/tmp/harness-tint on-statusline grok"
# <<< harness-tint <<<
EOF
cat >"$HARNESS_TINT_CODEX_HOOKS" <<'EOF'
{
  "hooks": {
    "SessionStart": [
      {"hooks": [{"type": "command", "command": "/tmp/harness-tint on-event codex", "timeout": 5}]}
    ]
  },
  "description": "Tint the terminal for the Codex model."
}
EOF
cat >"$HARNESS_TINT_AGY_SETTINGS" <<'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "/tmp/harness-tint on-statusline agy",
    "enabled": true
  },
  "model": "Gemini 3.8 Flash (High)"
}
EOF

"${HT[@]}" install >/dev/null
grep -q "share/zshrc.zsh" "$HARNESS_TINT_ZSHRC" && pass "zshrc wired" || fail "zshrc wired"
if grep -q "harness-tint" "$HARNESS_TINT_GROK_CONFIG" "$HARNESS_TINT_CLAUDE_SETTINGS" "$HARNESS_TINT_AGY_SETTINGS"; then
  fail "install removes model tinting"
else
  pass "install removes model tinting"
fi
[ ! -f "$HARNESS_TINT_CODEX_HOOKS" ] && pass "empty codex hooks file is removed" || fail "empty codex hooks file is removed"
python3 - "$HARNESS_TINT_CLAUDE_SETTINGS" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data["model"] == "sonnet"
assert data["theme"] == "dark"
assert data["hooks"]["SessionStart"][0]["hooks"][0]["command"] == "other-hook"
assert "PostModelSwitch" not in data["hooks"]
PY
pass "claude keeps its settings and other hooks"
python3 - "$HARNESS_TINT_GROK_CONFIG" <<'PY'
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
assert 'default = "grok-4.7"' in text
assert "status_line" not in text
PY
pass "grok config keeps the model"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["model"].startswith("Gemini") and "statusLine" not in d' "$HARNESS_TINT_AGY_SETTINGS"
pass "agy keeps its model"

for dest in \
  "$tmpdir/home/.grok/skills/terminal-color" \
  "$tmpdir/home/.claude/skills/terminal-color" \
  "$tmpdir/home/.codex/skills/terminal-color" \
  "$tmpdir/home/.gemini/config/skills/terminal-color" \
  "$tmpdir/home/.prime/agent/skills/terminal-color" \
  "$tmpdir/home/.config/muse/skills/terminal-color"
do
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$ROOT/skills/terminal-color" ]; then
    pass "skill linked at $dest"
  else
    fail "skill linked at $dest"
  fi
done
[ -L "$tmpdir/home/.local/bin/harness-tint" ] && pass "bin linked" || fail "bin linked"

bytes="$(wc -c <"$HARNESS_TINT_ZSHRC" | tr -d ' ')"
"${HT[@]}" install >/dev/null
count="$(grep -c ">>> harness-tint >>>" "$HARNESS_TINT_ZSHRC")"
expect_eq "install is idempotent" "1" "$count"
expect_eq "second install does not grow zshrc" "$bytes" "$(wc -c <"$HARNESS_TINT_ZSHRC" | tr -d ' ')"
doctor="$("${HT[@]}" doctor)"
printf '%s\n' "$doctor" | grep -q "colors: 100" && pass "doctor counts colors" || fail "doctor counts colors"
printf '%s\n' "$doctor" | grep -q "auto-tint: off" && pass "doctor reports auto-tint off" || fail "doctor reports auto-tint off"
printf '%s\n' "$doctor" | grep -q "skill claude: linked" && pass "doctor sees the skill" || fail "doctor sees the skill"

# A custom agy status line and a custom grok status line are left alone.
custom="$tmpdir/custom-agy.json"
printf '%s\n' '{"statusLine":{"type":"command","command":"my-status"},"model":"Gemini 3.8 Flash (High)"}' >"$custom"
custom_grok="$tmpdir/custom-grok.toml"
printf '%s\n' '[ui.status_line]' 'command = "my-status"' >"$custom_grok"
HARNESS_TINT_AGY_SETTINGS="$custom" HARNESS_TINT_GROK_CONFIG="$custom_grok" "${HT[@]}" install >/dev/null
grep -q "my-status" "$custom" && pass "custom agy status line is kept" || fail "custom agy status line is kept"
grep -q "harness-tint" "$custom" && fail "custom agy status line was replaced" || pass "custom agy status line was not replaced"
grep -q "my-status" "$custom_grok" && pass "custom grok status line is kept" || fail "custom grok status line is kept"

mkdir -p "$tmpdir/home/.claude/skills/terminal-color.foreign"
# Replacing the claude link with a real directory should be left in place.
rm -f "$tmpdir/home/.claude/skills/terminal-color"
mkdir -p "$tmpdir/home/.claude/skills/terminal-color"
printf 'keep\n' >"$tmpdir/home/.claude/skills/terminal-color/SKILL.md"
"${HT[@]}" install >/dev/null
if [ -L "$tmpdir/home/.claude/skills/terminal-color" ]; then
  fail "existing skill directory was replaced"
else
  pass "existing skill directory was left in place"
fi
grep -q keep "$tmpdir/home/.claude/skills/terminal-color/SKILL.md" && pass "existing skill text stays" || fail "existing skill text stays"

# Put the link back so uninstall has something that belongs to us, plus a foreign one.
rm -rf "$tmpdir/home/.claude/skills/terminal-color"
ln -s "$ROOT/skills/terminal-color" "$tmpdir/home/.claude/skills/terminal-color"
mkdir -p "$tmpdir/home/.grok/skills/other-skill"
printf 'other\n' >"$tmpdir/home/.grok/skills/other-skill/SKILL.md"

"${HT[@]}" uninstall >/dev/null
if grep -q "harness-tint" "$HARNESS_TINT_ZSHRC"; then
  fail "uninstall removes the shell block"
else
  pass "uninstall removes the shell block"
fi
if [ -L "$tmpdir/home/.grok/skills/terminal-color" ] || [ -L "$tmpdir/home/.local/bin/harness-tint" ]; then
  fail "uninstall removes our links"
else
  pass "uninstall removes our links"
fi
grep -q other "$tmpdir/home/.grok/skills/other-skill/SKILL.md" && pass "uninstall keeps other skills" || fail "uninstall keeps other skills"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["model"]=="sonnet"' "$HARNESS_TINT_CLAUDE_SETTINGS"
pass "uninstall keeps the claude model"

if [ "$failures" -eq 0 ]; then
  printf 'all tests passed\n'
else
  printf '%s failed\n' "$failures" >&2
  exit 1
fi
