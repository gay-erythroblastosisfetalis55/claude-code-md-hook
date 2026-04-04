Toggle the md-convert hook on or off for this session.

## Steps

1. Check if `.claude/.noconvert` exists in the project root

2. If it **exists** (hook is currently OFF):
   - Delete `.claude/.noconvert`
   - Confirm: "md-convert hook is now ON — PDFs and documents will be converted to markdown."

3. If it **does not exist** (hook is currently ON):
   - Create an empty `.claude/.noconvert` file
   - Confirm: "md-convert hook is now OFF — Claude Code will read files natively (including PDF vision rendering)."

Do not explain how the hook works unless asked. Just toggle and confirm the new state.
