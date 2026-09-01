local State = require("mcphub.state")

---@type MCPTool
local stage_lines_tool = {
    name = "stage_lines",
    description = [[Stage or unstage specific line ranges in a file using gitsigns. Each operation targets one changed hunk/line range in a loaded buffer.]],
    needs_confirmation_window = false,
    inputSchema = {
        type = "object",
        properties = {
            path = {
                type = "string",
                description = "File path to operate on",
            },
            action = {
                type = "string",
                enum = { "stage", "unstage" },
                description = "Whether to stage or unstage the selected ranges",
            },
            ranges = {
                type = "array",
                description = "1-based line ranges to stage/unstage, e.g. [{start=10,end=20}]",
                items = {
                    type = "object",
                    properties = {
                        start = { type = "integer", minimum = 1 },
                        ["end"] = { type = "integer", minimum = 1 },
                    },
                    required = { "start", "end" },
                },
            },
        },
        required = { "path", "action", "ranges" },
    },
    handler = function(req, res)
        local params = req.params or {}

        if not params.path or vim.trim(params.path) == "" then
            return res:error("Missing required parameter: path")
        end
        if params.action ~= "stage" and params.action ~= "unstage" then
            return res:error("Invalid action. Expected 'stage' or 'unstage'")
        end
        if type(params.ranges) ~= "table" or vim.tbl_isempty(params.ranges) then
            return res:error("Missing required parameter: ranges")
        end

        local ok_gs, gitsigns = pcall(require, "gitsigns")
        if not ok_gs then
            return res:error("gitsigns is not available")
        end

        local absolute_path = vim.fn.fnamemodify(params.path, ":p")
        local bufnr = vim.fn.bufnr(absolute_path, true)
        if bufnr <= 0 then
            return res:error("Could not resolve buffer for path: " .. params.path)
        end

        if not vim.api.nvim_buf_is_loaded(bufnr) then
            vim.fn.bufload(bufnr)
        end

        if not vim.api.nvim_buf_is_loaded(bufnr) then
            return res:error("Failed to load buffer for path: " .. params.path)
        end

        local method = params.action == "stage" and gitsigns.stage_hunk or gitsigns.undo_stage_hunk
        local changed = {}

        for i, range in ipairs(params.ranges) do
            local s = tonumber(range.start)
            local e = tonumber(range["end"])
            if not s or not e or s < 1 or e < 1 then
                return res:error(string.format("Invalid range at index %d", i))
            end
            if s > e then
                s, e = e, s
            end

            local ok_call, err = pcall(function()
                vim.api.nvim_buf_call(bufnr, function()
                    method({ s, e })
                end)
            end)
            if not ok_call then
                return res:error(string.format("Failed on range %d (%d-%d): %s", i, s, e, tostring(err)))
            end
            table.insert(changed, string.format("%d-%d", s, e))
        end

        local summary = string.format(
            "%s %d range(s) in %s: %s",
            params.action == "stage" and "Staged" or "Unstaged",
            #changed,
            params.path,
            table.concat(changed, ", ")
        )

        -- Optional refresh if configured by user and available
        local cfg = State.config and State.config.builtin_tools and State.config.builtin_tools.stage_lines or {}
        if cfg.refresh_after_apply and gitsigns.refresh then
            pcall(gitsigns.refresh)
        end

        res:text(summary):send()
    end,
}

return stage_lines_tool
