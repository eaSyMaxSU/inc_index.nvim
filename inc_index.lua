-- Lua function to perform visual block numbering
function visual_block_numbering()
	-- Get user input for format and start number
	vim.ui.input({ prompt = "Enter number format and start number (e.g., h0, d11): " }, function(input)
		if not input then -- User cancelled
			vim.notify("Numbering cancelled.", vim.log.levels.INFO, { title = "Visual Block Numbering" })
			return
		end

		local format_type = "d" -- Default to decimal
		local start_number_str = input
		if string.sub(input, 1, 1) == "h" then
			format_type = "h"
			start_number_str = string.sub(input, 2)
		elseif string.sub(input, 1, 1) == "d" then
			format_type = "d"
			start_number_str = string.sub(input, 2)
		end

		local start_number = tonumber(start_number_str, format_type == "h" and 16 or 10)
		if not start_number then
			vim.notify("Invalid start number.", vim.log.levels.ERROR, { title = "Visual Block Numbering" })
			return
		end

		-- Get visual selection range
		local start_pos = vim.fn.getpos("'<")
		local end_pos = vim.fn.getpos("'>")

		if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
			start_pos, end_pos = end_pos, start_pos -- Swap if start is after end
		end

		local start_row = start_pos[2]
		local start_col = start_pos[3]
		local end_row = end_pos[2]
		local end_col = end_pos[3]

		local current_number = start_number

		-- Iterate through lines in the visual block
		for row = start_row, end_row do
			local line = vim.fn.getline(row)
			local prefix = string.sub(line, 1, start_col - 1) -- Part of the line before the block
			local suffix = string.sub(line, end_col + 1) -- Part of the line after the block
			local block_content = string.sub(line, start_col, end_col) -- The selected block content

			local number_str
			if format_type == "h" then
				number_str = string.format("%x", current_number) -- Hexadecimal format
			else -- format_type == 'd' or default
				number_str = tostring(current_number) -- Decimal format
			end

			-- Ensure the number string fits within the selected block width, pad with spaces if needed
			local block_width = end_col - start_col + 1
			local padded_number_str = string.format("%-" .. block_width .. "s", number_str) -- Left-align and pad with spaces

			-- Construct the new line with the numbered block
			local new_line = prefix .. padded_number_str .. suffix

			-- Set the modified line back into the buffer
			vim.fn.setline(row, new_line)

			current_number = current_number + 1
		end

		vim.notify("Visual block numbering completed.", vim.log.levels.INFO, { title = "Visual Block Numbering" })
	end)
end
