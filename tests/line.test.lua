-- Function to get lines from start_row to end_row
function get_lines(start_row, end_row)
	-- Adjust for Lua's 1-based indexing
	local adjusted_start = start_row - 1
	local adjusted_end = end_row -- end_row is exclusive in nvim_buf_get_lines

	-- Use Neovim's API to get lines from the buffer
	local lines = vim.api.nvim_buf_get_lines(0, adjusted_start, adjusted_end, false)
	return lines
end

-- Example usage
local start_row = 1
local end_row = 5
local lines = get_lines(start_row, end_row)

-- Print the lines
for _, line in ipairs(lines) do
	print(line)
end
