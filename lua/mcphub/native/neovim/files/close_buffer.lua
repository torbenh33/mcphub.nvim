---@type MCPTool
local close_buffer_tool = {
    name = "close_buffer",
    description = "Close an existing Neovim buffer by buffer number or file path.",
    needs_confirmation_window = true,
    inputSchema = {
        type = "object",
        properties = {
            bufnr = {
                type = "number",
                description = "Buffer number to close",
            },
            path = {
                type = "string",
                description = "Path of the buffer to close",
            },
            force = {
                type = "boolean",
                description = "Force close even if buffer has unsaved changes",
                default = false,
            },
            wipe = {
                type = "boolean",
                description = "Use :bwipeout instead of :bdelete",
                default = false,
            },
        },
    },
    handler = function(req, res)
        local params = req.params or {}
        local force = params.force == true
        local wipe = params.wipe == true

        if params.bufnr == nil and (not params.path or vim.trim(params.path) == "") then
            return res:error("Provide either 'bufnr' or 'path'")
        end

        local bufnr = tonumber(params.bufnr)

        if not bufnr then
            local absolute_path = vim.fn.fnamemodify(params.path, ":p")
            bufnr = vim.fn.bufnr(absolute_path)
            if bufnr <= 0 then
                return res:error("No buffer found for path: " .. params.path)
            end
        end

        if not vim.api.nvim_buf_is_valid(bufnr) then
            return res:error("Invalid buffer: " .. tostring(bufnr))
        end

        local was_modified = vim.bo[bufnr].modified
        if was_modified and not force then
            return res:error("Buffer has unsaved changes. Set force=true to close it.")
        end

        local cmd = wipe and "bwipeout" or "bdelete"
        local ok, err = pcall(vim.cmd, string.format("silent %s%s %d", cmd, force and "!" or "", bufnr))
        if not ok then
            return res:error("Failed to close buffer: " .. tostring(err))
        end

        res:text(string.format("Closed buffer %d using :%s%s", bufnr, cmd, force and "!" or "")):send()
    end,
}

return close_buffer_tool
