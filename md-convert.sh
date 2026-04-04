#!/bin/bash
# md-convert.sh — PreToolUse hook for Read tool
# Intercepts reads of PDF/DOCX/XLSX/PPTX/HTML files, converts to markdown,
# caches in .cache/ next to source, and redirects Claude to the cached version.

export HOOK_INPUT=$(cat)

# Find system Python, explicitly bypassing any active venv
find_system_python() {
    for py in \
        /opt/homebrew/bin/python3 \
        /usr/local/bin/python3 \
        /usr/bin/python3 \
        "$LOCALAPPDATA/Programs/Python/Python312/python.exe" \
        "$LOCALAPPDATA/Programs/Python/Python311/python.exe" \
        "python3" \
        "python"
    do
        if [ -x "$py" ] 2>/dev/null || command -v "$py" &>/dev/null; then
            # Make sure it's not a venv python
            venv_py=$("$py" -c "import sys; print(sys.prefix != sys.base_prefix)" 2>/dev/null)
            if [ "$venv_py" = "False" ]; then
                echo "$py"
                return
            fi
        fi
    done
    # Last resort: use whatever python3 is available even if in a venv
    command -v python3 || command -v python
}

export SYSTEM_PYTHON=$(find_system_python)

if [ -z "$SYSTEM_PYTHON" ]; then
    exit 0
fi

"$SYSTEM_PYTHON" - <<'EOF'
import sys, json, os, subprocess, shutil

SYSTEM_PYTHON = os.environ.get('SYSTEM_PYTHON', 'python3')

# --- Parse hook input ---
try:
    data = json.loads(os.environ.get('HOOK_INPUT', '{}'))
except Exception:
    sys.exit(0)

file_path = data.get('tool_input', {}).get('file_path', '')
if not file_path:
    sys.exit(0)

# Resolve absolute path
file_path = os.path.abspath(file_path)
if not os.path.isfile(file_path):
    sys.exit(0)

# --- Check extension ---
ext = os.path.splitext(file_path)[1].lower()
if ext not in ('.pdf', '.docx', '.xlsx', '.pptx', '.html', '.htm'):
    sys.exit(0)

# --- Compute cache path ---
dir_name  = os.path.dirname(file_path)
base_name = os.path.basename(file_path)
cache_dir  = os.path.join(dir_name, '.cache')
cache_file = os.path.join(cache_dir, base_name + '.md')

# --- Serve from cache if fresh ---
if (os.path.isfile(cache_file) and
        os.path.getmtime(cache_file) > os.path.getmtime(file_path)):
    print(json.dumps({'updatedInput': {'file_path': cache_file}}))
    sys.exit(0)

# --- Locate markitdown CLI ---
def find_markitdown():
    cmd = shutil.which('markitdown')
    if cmd:
        return cmd
    home = os.path.expanduser('~')
    candidates = [
        os.path.join(home, '.local', 'bin', 'markitdown'),
        os.path.join(home, '.local', 'pipx', 'venvs', 'markitdown', 'bin', 'markitdown'),
        os.path.join(home, 'AppData', 'Roaming', 'Python', 'Scripts', 'markitdown.exe'),
        os.path.join(home, 'AppData', 'Local', 'Programs', 'Python', 'Scripts', 'markitdown.exe'),
    ]
    for path in candidates:
        if os.path.isfile(path):
            return path
    return None

# --- Check if markitdown importable via system python ---
def markitdown_importable():
    try:
        result = subprocess.run(
            [SYSTEM_PYTHON, '-c', 'from markitdown import MarkItDown'],
            capture_output=True, timeout=10
        )
        return result.returncode == 0
    except Exception:
        return False

markitdown_cmd = find_markitdown()

# --- Auto-install if missing ---
if not markitdown_cmd and not markitdown_importable():
    pipx = shutil.which('pipx')
    if pipx:
        try:
            subprocess.run([pipx, 'install', 'markitdown[pdf]'], capture_output=True, timeout=90)
        except Exception:
            pass
        markitdown_cmd = find_markitdown()

    if not markitdown_cmd:
        # Fall back to pip --user (works on non-Homebrew Python environments)
        try:
            subprocess.run(
                [SYSTEM_PYTHON, '-m', 'pip', 'install', 'markitdown[pdf]', '--user', '--quiet'],
                capture_output=True, timeout=90
            )
        except Exception:
            pass
        markitdown_cmd = find_markitdown()

# --- Convert ---
os.makedirs(cache_dir, exist_ok=True)
try:
    if markitdown_cmd:
        result = subprocess.run(
            [markitdown_cmd, file_path],
            capture_output=True, text=True, timeout=120
        )
    elif markitdown_importable():
        # Use Python API directly — most reliable, bypasses CLI PATH issues
        result = subprocess.run(
            [SYSTEM_PYTHON, '-c',
             f'from markitdown import MarkItDown; md = MarkItDown(); r = md.convert("{file_path}"); print(r.text_content)'],
            capture_output=True, text=True, timeout=120
        )
    else:
        sys.exit(0)

    if result.returncode == 0 and result.stdout.strip():
        with open(cache_file, 'w', encoding='utf-8') as f:
            f.write(result.stdout)
        print(json.dumps({'updatedInput': {'file_path': cache_file}}))
except Exception:
    pass

sys.exit(0)
EOF
