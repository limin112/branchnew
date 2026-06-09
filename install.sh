#!/usr/bin/env bash
#
# branchnew installer.
#
# One-liner (no clone needed):
#   curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/install.sh | bash -s -- --hotkey
# From a clone:
#   ./install.sh [--hotkey]
#
# Base install : the `branchnew` command + the `/branchnew` slash command.
# --hotkey also: the iTerm2 ⌘F fork daemon, and it wires the Claude hooks for you.
#
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/limin112/branchnew/main"

[[ "$(uname)" == "Darwin" ]] || { echo "branchnew is macOS-only." >&2; exit 1; }

WANT_HOTKEY=0
[[ "${1:-}" == "--hotkey" ]] && WANT_HOTKEY=1

# Source files: use the clone we're running from, otherwise download them.
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [[ -z "$SRC_DIR" || ! -f "$SRC_DIR/branchnew" ]]; then
  SRC_DIR="$(mktemp -d)"
  trap 'rm -rf "$SRC_DIR"' EXIT
  echo "↓ downloading branchnew from GitHub…"
  for f in branchnew commands/branchnew.md iterm2/claude_fork.py; do
    mkdir -p "$SRC_DIR/$(dirname "$f")"
    curl -fsSL "$REPO_RAW/$f" -o "$SRC_DIR/$f"
  done
fi

# 1) the branchnew command
DEST_DIR="$HOME/.local/bin"
DEST="$DEST_DIR/branchnew"
mkdir -p "$DEST_DIR"
install -m 0755 "$SRC_DIR/branchnew" "$DEST"
echo "✓ installed: $DEST"

case ":$PATH:" in
  *":$DEST_DIR:"*) echo "✓ $DEST_DIR is on PATH" ;;
  *)
    RC="$HOME/.zshrc"; LINE='export PATH="$HOME/.local/bin:$PATH"'
    if ! grep -qsF "$LINE" "$RC" 2>/dev/null; then
      printf '\n# added by branchnew installer\n%s\n' "$LINE" >> "$RC"
      echo "✓ added $DEST_DIR to PATH in $RC"
    fi
    echo "  → open a new terminal (or run: source $RC) to pick it up"
    ;;
esac

# 2) the /branchnew slash command
CMD_DIR="$HOME/.claude/commands"
mkdir -p "$CMD_DIR"
install -m 0644 "$SRC_DIR/commands/branchnew.md" "$CMD_DIR/branchnew.md"
echo "✓ installed /branchnew slash command"

command -v claude >/dev/null 2>&1 || echo "! note: 'claude' is not on PATH — install Claude Code."

# 3) optional: iTerm2 hotkey daemon + auto-wired hooks
if [[ "$WANT_HOTKEY" == 1 ]]; then
  AL="$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch"
  mkdir -p "$AL"
  install -m 0644 "$SRC_DIR/iterm2/claude_fork.py" "$AL/claude_fork.py"
  echo "✓ installed iTerm2 hotkey daemon"

  # Wire the two recorder hooks into ~/.claude/settings.json (idempotent, backed up).
  python3 - "$DEST" <<'PY' || true
import json, os, sys, shutil
dest = sys.argv[1]
p = os.path.expanduser("~/.claude/settings.json")
os.makedirs(os.path.dirname(p), exist_ok=True)
d = {}
if os.path.exists(p):
    shutil.copy(p, p + ".bak")
    try:
        with open(p) as f: d = json.load(f)
    except Exception:
        sys.exit("! ~/.claude/settings.json isn't valid JSON — add the hooks by hand (see HOTKEY-FORK.md).")
hooks = d.setdefault("hooks", {})
cmd = dest + " --record"
def ensure(ev):
    arr = hooks.setdefault(ev, [])
    if any(h.get("command", "").strip() == cmd for blk in arr for h in blk.get("hooks", [])):
        return False
    arr.append({"hooks": [{"type": "command", "command": cmd}]}); return True
changed = ensure("SessionStart") | ensure("UserPromptSubmit")
with open(p, "w") as f: json.dump(d, f, indent=2, ensure_ascii=False)
print("✓ wired SessionStart/UserPromptSubmit → branchnew --record" if changed else "✓ hooks already wired")
PY

  echo
  echo "Almost there — two one-time manual bits for the hotkey:"
  echo "  1. iTerm2 → Settings → General → Magic → enable \"Enable Python API\""
  echo "  2. Restart iTerm2 and click \"Allow\" when it asks about claude_fork.py"
  echo "  Then open a Claude session and press ⌘F.   (details: HOTKEY-FORK.md)"
fi

echo
echo "Done.  Inside Claude Code type  /branchnew  — or run  branchnew --help"
