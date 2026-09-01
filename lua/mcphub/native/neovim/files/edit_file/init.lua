local State = require("mcphub.state")
---New modular editor tool using EditSession
---@type MCPTool
local edit_file_tool = {
    name = "edit_file",
    description = [[Replace one or more exact file sections using SEARCH/REPLACE blocks. Each SEARCH block must match the target file text exactly (character-for-character). The tool runs an interactive Neovim edit session and returns a diff plus parsing/feedback. Use an empty SEARCH block only to replace the entire file. Read the full guidelines in the diff description below for examples, escaping rules, and safe prompting templates.]],
    needs_confirmation_window = false, -- will show interactive diff, avoid double confirmations
    inputSchema = {
        type = "object",
        properties = {
            path = {
                type = "string",
                description = "The path to the file to modify",
            },
            diff = {
                type = "string",
                description = [[- Purpose and behavior
  - Each change must be provided as one SEARCH/REPLACE block using this exact format:

<<<<<<<< SEARCH
[exact text to find]
=======
[text to replace with]
>>>>>>> REPLACE

  - Parser behavior
    - The parser matches SEARCH blocks exactly (including whitespace, indentation, and line endings).
    - Only the first match per SEARCH block is replaced. To modify repeated content, provide multiple SEARCH/REPLACE blocks in the file's top-to-bottom order.
    - Blocks must be listed from top to bottom within the file.
    - The markers MUST be on their own lines.
  - Empty SEARCH block (nothing between SEARCH and =======) replaces the entire file; use it only when you want a full-file overwrite.

- Escaping
  - If your SEARCH or REPLACE text contains the literal marker lines (<<<<<<<, =======, >>>>>>>), escape each marker by prefixing a backslash (e.g., \<<<<<<<).

- Best practices (to get success on first try)
  1. If possible, read the file first and copy exact anchor lines into SEARCH blocks.
  2. Prefer short, unique anchors (one or two complete lines) rather than large contexts.
  3. To insert after a line L: set SEARCH to the exact L and REPLACE to L plus the inserted lines.
  4. To replace a multi-line region, copy the exact region into SEARCH.
  5. For multiple edits, provide multiple blocks in top-to-bottom order.

- Examples (exact, minimal)
  Insert lines after a unique anchor line:
<<<<<<<< SEARCH
require('avante').setup({
=======
require('avante').setup({
-- NEW: file header inserted here
>>>>>>> REPLACE

  Replace an exact function block:
<<<<<<<< SEARCH
def old():
    pass
=======
def old():
    # new implementation
    return 42
>>>>>>> REPLACE

  Full-file replace (explicit confirmation required from user):
<<<<<<<< SEARCH
(empty)
=======
<full new file content here>
>>>>>>> REPLACE

- Error handling & feedback you can expect
  - If a SEARCH block cannot be found: the tool will return the best-match context and indicate which block failed.
  - If markers are malformed or order is invalid: the parser will return a parsing error with details.
  - The tool will always return a BEFORE vs AFTER diff and any diagnostics; treat that output as authoritative.
]],
            },
        },
        required = { "path", "diff" },
    },
    handler = function(req, res)
        local params = req.params
        if not params.path or vim.trim(params.path) == "" then
            return res:error("Missing required parameter: path")
        end
        if not params.diff or vim.trim(params.diff) == "" then
            return res:error("Missing required parameter: diff")
        end
        -- Handle hub UI cleanup
        if req.caller and req.caller.type == "hubui" then
            req.caller.hubui:cleanup()
        end
        local EditSession = require("mcphub.native.neovim.files.edit_file.edit_session")
        local session = EditSession.new(params.path, params.diff, State.config.builtin_tools.edit_file)
        session:start({
            interactive = req.caller.auto_approve ~= true,
            on_success = function(summary)
                res:text(summary):send()
            end,
            on_error = function(error_report)
                res:error(error_report)
            end,
        })
    end,
}

return edit_file_tool

