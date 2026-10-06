# Adding Resources

Resources provide data through URIs in two ways:
1. Static Resources - Fixed URIs
2. Resource Templates - Dynamic URIs with parameters

## Type Definitions

### Static Resources
```lua
---@class MCPResource
---@field name? string Resource identifier
---@field description? string|fun():string Resource description
---@field mimeType? string Resource MIME type (e.g., "text/plain")
---@field dynamic? boolean Whether the resource content is dynamic
---@field uri string Static URI (e.g., "system://info")
---@field handler fun(req: ResourceRequest, res: ResourceResponse) Implementation
```

### Resource Templates
```lua
---@class MCPResourceTemplate
---@field name? string Template identifier
---@field description? string|fun():string Template description
---@field mimeType? string Default MIME type
---@field dynamic? boolean Whether the resource content is dynamic
---@field uriTemplate string URI with parameters (e.g., "buffer://{bufnr}/lines")
---@field handler fun(req: ResourceRequest, res: ResourceResponse) Implementation
```

#### Request Context

Resource handlers receive:

```lua
---@class ResourceRequest
---@field params table<string,string> Template parameters from URI
---@field uri string Complete requested URI
---@field uriTemplate string|nil Original template if from template
---@field resource MCPResource|MCPResourceTemplate Complete definition
---@field server NativeServer Server instance
---@field caller table Additional context from caller
---@field editor_info EditorInfo Current editor state
```

#### Response Builder

Resource handlers use:

```lua
---@class ResourceResponse
---@field text fun(text: string, mime?: string): ResourceResponse Add text
---@field blob fun(data: string, mime?: string): ResourceResponse Add binary
---@field image fun(data: string, mime?: string): ResourceResponse Add image
---@field audio fun(data: string, mime?: string): ResourceResponse Add audio
---@field error fun(message: string, details?: table): table Send error
---@field send fun(result?: table): table Send final response
```

## Examples

### Basic Examples

#### Static Resource

```lua
mcphub.add_resource("system", {
    name = "System Info",
    description = "Get system information",
    uri = "system://info",
    mimeType = "text/plain",
    handler = function(req, res)
        local info = {
            os = vim.loop.os_uname(),
            pid = vim.fn.getpid(),
            vimdir = vim.fn.stdpath("config")
        }
        return res:text(vim.inspect(info)):send()
    end
})
```

#### Resource Template

```lua
mcphub.add_resource_template("files", {
    name = "File Lines",
    description = "Get specific lines from a file",
    uriTemplate = "files://{path}/{start}-{end}",
    handler = function(req, res)
        -- Get parameters
        local path = req.params.path
        local start_line = tonumber(req.params.start)
        local end_line = tonumber(req.params.end)
        
        -- Validate file
        if not vim.loop.fs_stat(path) then
            return res:error("File not found: " .. path)
        end
        
        -- Read lines
        local lines = {}
        local current = 0
        for line in io.lines(path) do
            current = current + 1
            if current >= start_line then
                table.insert(lines, string.format(
                    "%4d │ %s", current, line
                ))
            end
            if current >= end_line then
                break
            end
        end
        
        return res:text(table.concat(lines, "\n")):send()
    end
})
```

### Real Examples from Neovim Server

#### LSP Diagnostics Resource

```lua
mcphub.add_resource("neovim", {
    name = "Diagnostics: Current File",
    description = "Get diagnostics for the current file",
    uri = "neovim://diagnostics/current",
    mimeType = "text/plain",
    handler = function(req, res)
        -- Get active buffer
        local buf_info = req.editor_info.last_active
        if not buf_info then
            return res:error("No active buffer")
        end

        -- Get diagnostics
        local diagnostics = vim.diagnostic.get(buf_info.bufnr)
        
        -- Format header
        local text = string.format(
            "Diagnostics for: %s\n%s\n",
            buf_info.filename,
            string.rep("-", 40)
        )
        
        -- Format diagnostics
        for _, diag in ipairs(diagnostics) do
            local severity = vim.diagnostic.severity[diag.severity]
            text = text .. string.format(
                "\n%s: %s\nLine %d: %s\n",
                severity,
                diag.source or "unknown",
                diag.lnum + 1,
                diag.message
            )
        end

        return res:text(text):send()
    end
})
```

#### Buffer Lines Template

```lua
mcphub.add_resource_template("neovim", {
    name = "Buffer Lines",
    description = "Get specific lines from a buffer",
    uriTemplate = "neovim://buffer/{bufnr}/lines/{start}-{end}",
    handler = function(req, res)
        -- Get parameters
        local bufnr = tonumber(req.params.bufnr)
        local start_line = tonumber(req.params.start)
        local end_line = tonumber(req.params.end)
        
        -- Validate buffer
        if not vim.api.nvim_buf_is_valid(bufnr) then
            return res:error("Invalid buffer: " .. req.params.bufnr)
        end
        
        -- Get lines
        local lines = vim.api.nvim_buf_get_lines(
            bufnr,
            start_line - 1,  -- 0-based index
            end_line,       -- Exclusive end
            false          -- Strict indexing
        )
        
        -- Format with line numbers
        local result = {}
        for i, line in ipairs(lines) do
            table.insert(result, string.format(
                "%4d │ %s",
                start_line + i - 1,
                line
            ))
        end
        
        return res:text(table.concat(result, "\n")):send()
    end
})
```

## Advanced Features

#### Dynamic MIME Types

Change MIME type based on content:

```lua
mcphub.add_resource_template("files", {
    name = "File Content",
    uriTemplate = "files://{path}",
    handler = function(req, res)
        local path = req.params.path
        local ext = vim.fn.fnamemodify(path, ":e")
        
        -- Get MIME type based on extension
        local mime_types = {
            json = "application/json",
            yaml = "application/yaml",
            md = "text/markdown",
            txt = "text/plain"
        }
        
        local mime = mime_types[ext] or "text/plain"
        return res:text(vim.fn.readfile(path), mime):send()
    end
})
```

#### Binary Data

Handle binary files:

```lua
mcphub.add_resource_template("files", {
    name = "File Download",
    uriTemplate = "files://download/{path}",
    handler = function(req, res)
        local path = req.params.path
        local ext = vim.fn.fnamemodify(path, ":e")
        
        -- Binary file types
        local binary_types = {
            png = "image/png",
            jpg = "image/jpeg",
            pdf = "application/pdf"
        }
        
        if binary_types[ext] then
            -- Read as binary
            local data = vim.fn.readfile(path, "b")
            return res:blob(data, binary_types[ext]):send()
        else
            -- Read as text
            return res:text(vim.fn.readfile(path)):send()
        end
    end
})
```

#### Resource Validation

URI parameter validation:

```lua
mcphub.add_resource_template("git", {
    name = "Commit Info",
    uriTemplate = "git://commit/{hash}",
    handler = function(req, res)
        local hash = req.params.hash
        
        -- Validate hash format
        if not hash:match("^[0-9a-f]+$") then
            return res:error("Invalid commit hash", {
                hash = hash,
                expected = "hexadecimal string"
            })
        end
        
        -- Validate hash exists
        local exists = vim.fn.system(
            "git rev-parse --quiet --verify " .. hash
        )
        if vim.v.shell_error ~= 0 then
            return res:error("Commit not found", {
                hash = hash,
                suggestion = "Use 'git log' to list commits"
            })
        end
        
        -- Get commit info
        local info = vim.fn.system(
            "git show --no-patch --format='%h %s' " .. hash
        )
        return res:text(info):send()
    end
})
```
Next, learn about [Adding Prompts](./prompts) to create interactive conversations.
