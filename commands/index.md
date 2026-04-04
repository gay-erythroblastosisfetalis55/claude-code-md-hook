Generate a structural index for a file and cache it for section-by-section reading.

## Steps

1. Get the file path from $ARGUMENTS. If not provided, ask the user.

2. Check if `.cache/<filename>.md` exists next to the original file and is newer than the original.
   - If yes: use the cached file directly.
   - If no and the file is a PDF/DOCX/XLSX/PPTX/HTML: run `markitdown <file_path>` via Bash, save output to `.cache/<filename>.md` next to the original file.
   - If no and the file is already a `.md`: use the file itself as the target.

3. Extract all headings from the target `.md` file using Bash:
   ```bash
   grep -n "^#" <target_file>
   ```

4. Display the index in this format:
   ```
   L{line_number}  {heading text}
   ```

5. Tell the user the cached path and how to read sections:
   > Cached at: `<cache_path>`
   > Use Read with `offset` and `limit` to fetch sections by line number.
