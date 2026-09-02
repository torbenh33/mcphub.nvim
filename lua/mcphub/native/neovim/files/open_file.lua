---@type MCPTool
local open_file_tool = {
    name = "open_file",
    description = "Open a file into a Neovim buffer so its contents and diagnostics are available.",
    needs_confirmation_window = true,
    inputSchema = {
        type = "object",
        properties = {
            path = {
                type = "string",
                description = "Path to the file to open",
            },
        },
        required = { "path" },
    },
    handler = function(req, res)
        local params = req.params or {}

        if not params.path or vim.trim(params.path) == "" then
            return res:error("Missing required parameter: path")
        end

        local absolute_path = vim.fn.fnamemodify(params.path, ":p")
        if vim.fn.filereadable(absolute_path) == 0 then
            return res:error("File does not exist or is not readable: " .. params.path)
        end

        local bufnr = vim.fn.bufadd(absolute_path)
        if bufnr <= 0 then
            return res:error("Failed to create buffer for path: " .. params.path)
        end

        local ok_load, err = pcall(vim.fn.bufload, bufnr)
        if not ok_load then
            return res:error("Failed to load buffer: " .. tostring(err))
        end

        if not vim.api.nvim_buf_is_loaded(bufnr) then
            return res:error("Buffer is not loaded for path: " .. params.path)
        end

        res:text(string.format("Opened %s in buffer %d", params.path, bufnr)):send()
    end,
}

return open_file_tool
