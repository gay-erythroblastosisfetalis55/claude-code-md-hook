#!/bin/bash
# install.sh — claude-code-md-hook installer
# Installs md-convert.sh and patches .claude/settings.json
#
# Usage:
#   Project-level (default):  bash install.sh
#   Global (all projects):    bash install.sh --global

set -e

GLOBAL=false
for arg in "$@"; do
    case $arg in
        --global) GLOBAL=true ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/md-convert.sh"

# Download md-convert.sh if running via curl pipe (script not on disk)
if [ ! -f "$HOOK_SCRIPT" ]; then
    HOOK_SCRIPT="$(mktemp /tmp/md-convert.XXXXXX.sh)"
    DOWNLOAD=true
    curl -sSL "https://raw.githubusercontent.com/sunlesshalo/claude-code-md-hook/main/md-convert.sh" -o "$HOOK_SCRIPT"
fi

echo "claude-code-md-hook installer"
echo "=============================="

# --- Determine install target ---
if [ "$GLOBAL" = true ]; then
    TARGET_DIR="$HOME/.claude"
    SCRIPTS_DIR="$HOME/.claude/scripts"
    SETTINGS_JSON="$HOME/.claude/settings.json"
    HOOK_COMMAND="bash $HOME/.claude/scripts/md-convert.sh"
    echo "Mode: global (applies to all Claude Code projects)"
else
    TARGET_DIR="$(pwd)"
    SCRIPTS_DIR="$(pwd)/scripts"
    SETTINGS_JSON="$(pwd)/.claude/settings.json"
    HOOK_COMMAND="bash scripts/md-convert.sh"
    echo "Mode: project (applies to current directory only)"
    echo "Directory: $TARGET_DIR"
fi

echo ""

# --- Install the script ---
mkdir -p "$SCRIPTS_DIR"
cp "$HOOK_SCRIPT" "$SCRIPTS_DIR/md-convert.sh"
chmod +x "$SCRIPTS_DIR/md-convert.sh"
echo "✓ Installed md-convert.sh → $SCRIPTS_DIR/md-convert.sh"

# Clean up temp download if needed
if [ "${DOWNLOAD:-false}" = true ]; then
    rm -f "$HOOK_SCRIPT"
fi

# --- Patch settings.json ---
mkdir -p "$(dirname "$SETTINGS_JSON")"

# Use Python to safely merge — avoids clobbering existing settings
python3 - <<PYEOF
import json, os, sys

settings_path = "$SETTINGS_JSON"
hook_command = "$HOOK_COMMAND"

new_hook = {"type": "command", "command": hook_command}
new_matcher = {"matcher": "Read", "hooks": [new_hook]}

# Load existing config or start fresh
if os.path.isfile(settings_path):
    try:
        with open(settings_path) as f:
            config = json.load(f)
    except Exception:
        print("  Warning: could not parse existing settings.json — creating backup and starting fresh")
        import shutil
        shutil.copy(settings_path, settings_path + ".bak")
        config = {}
else:
    config = {}

if "hooks" not in config:
    config["hooks"] = {}

pre = config["hooks"].setdefault("PreToolUse", [])

# Check if already installed
for entry in pre:
    if entry.get("matcher") == "Read":
        for h in entry.get("hooks", []):
            if h.get("command") == hook_command:
                print("  Already installed — nothing to do.")
                sys.exit(0)
        # Matcher exists but our hook isn't in it — append
        entry["hooks"].append(new_hook)
        break
else:
    # No Read matcher yet — add one
    pre.append(new_matcher)

with open(settings_path, "w") as f:
    json.dump(config, f, indent=2)

print("✓ Patched " + settings_path)
PYEOF

echo ""
echo "Done! Restart Claude Code for the hook to take effect."
echo ""
echo "What it does:"
echo "  • PDF/DOCX/XLSX/PPTX/HTML → auto-converted to markdown (10-20x token savings)"
echo "  • Markdown files >300 lines → structural index served, targeted reads only"
echo ""
echo "To uninstall: bash uninstall.sh"
