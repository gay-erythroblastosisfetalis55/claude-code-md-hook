# claude-code-md-hook

A Claude Code hook that automatically handles two of the biggest token waste sources:

1. **Document conversion** — PDFs, Word docs, spreadsheets, and other files are converted to markdown before Claude reads them. A raw PDF can use 10–20x more tokens than its markdown equivalent.

2. **Large file indexing** — Markdown files over 300 lines are intercepted and replaced with a structural index (headings + line numbers). Claude reads only the relevant section instead of the whole file.

Both behaviors are silent, cached, and require zero changes to your workflow.

Supported formats for conversion: `.pdf` `.docx` `.xlsx` `.pptx` `.html` `.htm`

---

## Install

### Option 1 — One command (easiest)

Open a terminal, navigate to your Claude Code project folder, and run:

```bash
curl -sSL https://raw.githubusercontent.com/sunlesshalo/claude-code-md-hook/main/install.sh | bash
```

That's it. Restart Claude Code and the hook is active.

> **Want it active across all your projects?** Add `--global`:
> ```bash
> curl -sSL https://raw.githubusercontent.com/sunlesshalo/claude-code-md-hook/main/install.sh | bash -s -- --global
> ```

---

### Option 2 — Manual (if you want to inspect everything first)

**Step 1** — Copy `md-convert.sh` into your project's `scripts/` folder:

```bash
mkdir -p scripts
curl -sSL https://raw.githubusercontent.com/sunlesshalo/claude-code-md-hook/main/md-convert.sh -o scripts/md-convert.sh
chmod +x scripts/md-convert.sh
```

**Step 2** — Add the hook to `.claude/settings.json`.

If you **don't have a settings.json yet**, create `.claude/settings.json` with this content:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "bash scripts/md-convert.sh"
          }
        ]
      }
    ]
  }
}
```

If you **already have a settings.json**, add only the new matcher inside your existing `PreToolUse` array:

```json
{
  "matcher": "Read",
  "hooks": [
    {
      "type": "command",
      "command": "bash scripts/md-convert.sh"
    }
  ]
}
```

**Step 3** — Restart Claude Code.

---

## How it works

### Document conversion

1. When Claude tries to read a file, the `PreToolUse` hook fires first
2. The hook checks the file extension — if it's a supported format, it converts it to markdown using [markitdown](https://github.com/microsoft/markitdown)
3. The converted markdown is cached in a `.cache/` folder next to the original file
4. Claude receives the path to the cached markdown file instead of the original
5. On subsequent reads, the cache is served instantly (until the original file changes)

**First run** installs `markitdown` automatically if it isn't already on your system (via `pipx` or `pip --user`). No manual setup needed.

### Large file indexing

1. If a file (including a freshly converted `.md`) exceeds 300 lines, the hook blocks the full read
2. It generates a structural index: every markdown heading with its line number
3. The index is cached next to the source file
4. Claude receives the index and uses `offset`/`limit` to fetch only the relevant section
5. The cache is invalidated automatically when the file is modified

Targeted reads (those that already specify `offset` or `limit`) always pass through — the hook only blocks unfiltered reads of large files.

---

## Migrating from an earlier version

Earlier versions of this hook wrote to `.claude/hooks.json`. That file is **not read by Claude Code** — hooks must live in `.claude/settings.json`.

If you installed the old version, run the installer again — it will patch `settings.json` correctly. You can safely delete any `.claude/hooks.json` file left over from the old install.

---

## Uninstall

```bash
curl -sSL https://raw.githubusercontent.com/sunlesshalo/claude-code-md-hook/main/uninstall.sh | bash
```

Or for a global install:

```bash
curl -sSL https://raw.githubusercontent.com/sunlesshalo/claude-code-md-hook/main/uninstall.sh | bash -s -- --global
```

---

## Requirements

- Claude Code
- Python 3 (almost certainly already installed)
- `pipx` or `pip` (for auto-installing markitdown on first use)

---

## License

MIT
