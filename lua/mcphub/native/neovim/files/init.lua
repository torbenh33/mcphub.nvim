local mcphub = require("mcphub")

-- Import individual tools and resources
local buffer_resource = require("mcphub.native.neovim.files.buffer")
local edit_file_tool = require("mcphub.native.neovim.files.edit_file")
local environment_resource = require("mcphub.native.neovim.files.environment")
local file_tools = require("mcphub.native.neovim.files.operations")
local search_tools = require("mcphub.native.neovim.files.search")
local write_tool = require("mcphub.native.neovim.files.write")
local stage_lines_tool = require("mcphub.native.neovim.files.stage_lines")

mcphub.add_resource("neovim", buffer_resource)
mcphub.add_resource("neovim", environment_resource)

for _, tool in ipairs(file_tools) do
    mcphub.add_tool("neovim", tool)
end
for _, tool in ipairs(search_tools) do
    mcphub.add_tool("neovim", tool)
end

mcphub.add_tool("neovim", edit_file_tool)
mcphub.add_tool("neovim", write_tool)
mcphub.add_tool("neovim", stage_lines_tool)
