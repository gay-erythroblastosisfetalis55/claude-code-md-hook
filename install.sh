#!/bin/bash
# install.sh — claude-code-md-hook installer
# Installs md-convert.sh, /noconvert and /index commands, and patches .claude/settings.json
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
COMMANDS_SRC="$SCRIPT_DIR/commands"

BASE_URL="https://raw.githubusercontent.com/sunlesshalo/claude-code-md-hook/main"

# Download md-convert.sh if running via curl pipe (script not on disk)
if [ ! -f "$HOOK_SCRIPT" ]; then
    HOOK_SCRIPT="$(mktemp /tmp/md-convert.XXXXXX.sh)"
    DOWNLOAD_SCRIPT=true
    curl -sSL "$BASE_URL/md-convert.sh" -o "$HOOK_SCRIPT"
fi

echo "claude-code-md-hook installer"
echo "=============================="

# --- Determine install target ---
if [ "$GLOBAL" = true ]; then
    TARGET_DIR="$HOME/.claude"
    SCRIPTS_DIR="$HOME/.claude/scripts"
    COMMANDS_DIR="$HOME/.claude/commands"
    SETTINGS_JSON="$HOME/.claude/settings.json"
    HOOK_COMMAND="bash $HOME/.claude/scripts/md-convert.sh"
    echo "Mode: global (applies to all Claude Code projects)"
else
    TARGET_DIR="$(pwd)"
    SCRIPTS_DIR="$(pwd)/scripts"
    COMMANDS_DIR="$(pwd)/.claude/commands"
    SETTINGS_JSON="$(pwd)/.claude/settings.json"
    HOOK_COMMAND="bash scripts/md-convert.sh"
    echo "Mode: project (applies to current directory only)"
    echo "Directory: $TARGET_DIR"
fi

echo ""

# --- Install the hook script ---
mkdir -p "$SCRIPTS_DIR"
cp "$HOOK_SCRIPT" "$SCRIPTS_DIR/md-convert.sh"
chmod +x "$SCRIPTS_DIR/md-convert.sh"
echo "✓ Installed md-convert.sh → $SCRIPTS_DIR/md-convert.sh"

if [ "${DOWNLOAD_SCRIPT:-false}" = true ]; then
    rm -f "$HOOK_SCRIPT"
fi

# --- Install slash commands ---
mkdir -p "$COMMANDS_DIR"

for cmd in noconvert index; do
    CMD_FILE="$COMMANDS_DIR/${cmd}.md"
    if [ -f "$COMMANDS_SRC/${cmd}.md" ]; then
        cp "$COMMANDS_SRC/${cmd}.md" "$CMD_FILE"
    else
        curl -sSL "$BASE_URL/commands/${cmd}.md" -o "$CMD_FILE"
    fi
    echo "✓ Installed /${cmd} command → $CMD_FILE"
done

# --- Patch settings.json ---
mkdir -p "$(dirname "$SETTINGS_JSON")"

python3 - <<PYEOF
import json, os, sys

settings_path = "$SETTINGS_JSON"
hook_command = "$HOOK_COMMAND"

new_hook = {"type": "command", "command": hook_command}
new_matcher = {"matcher": "Read", "hooks": [new_hook]}

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

for entry in pre:
    if entry.get("matcher") == "Read":
        for h in entry.get("hooks", []):
            if h.get("command") == hook_command:
                print("  Already installed — nothing to do.")
                sys.exit(0)
        entry["hooks"].append(new_hook)
        break
else:
    pre.append(new_matcher)

with open(settings_path, "w") as f:
    json.dump(config, f, indent=2)

print("✓ Patched " + settings_path)
PYEOF

echo ""
echo "Done! Restart Claude Code for the hook to take effect."
echo ""
echo "What it does:"
echo "  • PDF/DOCX/XLSX/PPTX/HTML → converted to markdown (avoids vision token overhead)"
echo "  • Markdown files >300 lines → structural index served, targeted reads only"
echo "  • /noconvert → toggle conversion off/on (e.g. for visual PDFs)"
echo "  • /index <file> → manually cache and index any file"
echo ""
echo "To uninstall: bash uninstall.sh"
