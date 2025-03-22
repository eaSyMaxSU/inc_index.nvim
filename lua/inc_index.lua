local M = {}

function M.inc_index()
	-- Get user input for format and start number
	vim.ui.input({ prompt = "Enter format and start number (d[decimal], h[hex], a[alphabet]): " }, function(input)
		if not input then
			vim.notify("Numbering cancelled.", vim.log.levels.INFO, { title = "Incrementing Visual Blocks" })
			return
		end

		local format_type = "d" -- Default to decimal
		local start_char = nil
		local start_number_str = input
		if string.sub(input, 1, 1) == "h" then
			format_type = "h"
			start_number_str = string.sub(input, 2)
		elseif string.sub(input, 1, 1) == "d" then
			format_type = "d"
			start_number_str = string.sub(input, 2)
		elseif string.sub(input, 1, 1) == "a" then
			if string.sub(input, 2, 2) == "a" then
				format_type = "aa"
				start_char = "a"
				start_number_str = string.sub(input, 3) or "0" -- default start number.
			elseif string.sub(input, 2, 2) == "A" then
				format_type = "aA"
				start_char = "A"
				start_number_str = string.sub(input, 3) or "0"
			else
				vim.notify(
					"Invalid format. Use h, d, aa, or aA.",
					vim.log.levels.ERROR,
					{ title = "Incrementing Visual Blocks" }
				)
				return
			end
		end

		local start_number = tonumber(start_number_str, (format_type == "h" and 16) or 10)
		if not start_number and format_type ~= "aa" and format_type ~= "aA" then
			vim.notify("Invalid start number.", vim.log.levels.ERROR, { title = "Incrementing Visual Blocks" })
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
		local current_char = start_char

		-- Iterate through lines in the visual block
		for row = start_row, end_row do
			local line = vim.fn.getline(row)
			local prefix = string.sub(line, 1, start_col - 1) -- Part of the line before the block
			local suffix = string.sub(line, end_col + 1) -- Part of the line after the block
			local block_content = string.sub(line, start_col, end_col) -- The selected block content

			local number_str
			if format_type == "h" then
				number_str = string.format("%x", current_number) -- Hexadecimal format
			elseif format_type == "d" then
				number_str = tostring(current_number) -- Decimal format
			elseif format_type == "aa" or format_type == "aA" then
				number_str = string.char(string.byte(current_char)) -- Use the current character
				current_char = string.char(string.byte(current_char) + 1) -- Increment for the next line
				if string.byte(current_char) > (format_type == "aa" and string.byte("z") or string.byte("Z")) + 1 then -- Added + 1 to check after increment
					vim.notify(
						"Maximum character reached.",
						vim.log.levels.ERROR,
						{ title = "Incrementing Visual Blocks" }
					)
					return
				end
			end

			-- Ensure the number string fits within the selected block width, pad with spaces if needed
			local block_width = end_col - start_col + 1
			local padded_number_str = string.format("%-" .. block_width .. "s", number_str) -- Left-align and pad with spaces

			-- Construct the new line with the numbered block
			local new_line = prefix .. padded_number_str .. suffix

			-- Set the modified line back into the buffer
			vim.fn.setline(row, new_line)
			if format_type == "h" or format_type == "d" then
				current_number = current_number + 1
			end
		end

		vim.notify("Visual block numbering completed.", vim.log.levels.INFO, { title = "Incrementing Visual Blocks" })
	end)
end

function M.setup()
	vim.api.nvim_create_user_command("IncIndex", M.inc_index, {
		desc = "Number lines in a visual block",
		range = "%",
	})

	vim.keymap.set("v", "<leader>ic", ":IncIndex<CR>", { desc = "Increment Index in Visual Block" })
end

return M
