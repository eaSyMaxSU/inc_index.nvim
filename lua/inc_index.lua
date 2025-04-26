local M = {}

local api = vim.api
local fn = vim.fn
local ui = vim.ui
local notify = vim.notify
local log_levels = vim.log.levels -- Cache log levels
local cmd = vim.cmd

local string_sub = string.sub
local string_byte = string.byte
local string_char = string.char
local string_format = string.format
local string_match = string.match
local tonumber = tonumber
local tostring = tostring
local math_min = math.min
local table_insert = table.insert
local ipairs = ipairs

-- Core function to perform the incrementing
function M.inc_index()
	-- Get user input for format and start value
	ui.input({ prompt = "Format: d<num>, h<hex>, a<char>: " }, function(input)
		-- Check for nil or empty input
		if not input or #input < 1 then
			notify("Numbering cancelled or invalid input.", log_levels.INFO, { title = "Incrementing Visual Blocks" })
			return
		end

		local format_type = nil
		local start_char = nil
		local start_number = 0
		local input_value_str = ""

		local first_char = string_sub(input, 1, 1)
		local second_char_str = #input >= 2 and string_sub(input, 2, 2) or nil
		local rest_of_input = #input >= 2 and string_sub(input, 2) or ""

		-- Determine format and validate structure
		if first_char == "d" then
			format_type = "d"
			input_value_str = rest_of_input
		elseif first_char == "h" then
			format_type = "h"
			input_value_str = rest_of_input
		elseif first_char == "a" then
			if #input ~= 2 then
				notify(
					"Invalid format for 'a'. Use 'a' followed by a single letter (e.g., 'ag' or 'aG').",
					log_levels.ERROR,
					{ title = "Incrementing Visual Blocks" }
				)
				return
			end
			input_value_str = second_char_str

			if string_match(input_value_str, "%l") then
				format_type = "aa"
			elseif string_match(input_value_str, "%u") then
				format_type = "aA"
			else
				notify(
					"Invalid start character for 'a' format. Expected a single letter after 'a' (e.g., 'ag' or 'aG').",
					log_levels.ERROR,
					{ title = "Incrementing Visual Blocks" }
				)
				return
			end
			start_char = input_value_str
		else
			format_type = "d"
			input_value_str = input
		end

		-- Parse and validate the starting value itself
		if format_type == "d" then
			if not input_value_str or input_value_str == "" then
				notify(
					"Missing start number for decimal format.",
					log_levels.ERROR,
					{ title = "Incrementing Visual Blocks" }
				)
				return
			end
			start_number = tonumber(input_value_str)
			if not start_number then
				notify(
					"Invalid start number for decimal format.",
					log_levels.ERROR,
					{ title = "Incrementing Visual Blocks" }
				)
				return
			end
		elseif format_type == "h" then
			if not input_value_str or input_value_str == "" then
				notify(
					"Missing start number for hex format.",
					log_levels.ERROR,
					{ title = "Incrementing Visual Blocks" }
				)
				return
			end
			start_number = tonumber(input_value_str, 16)
			if not start_number then
				notify(
					"Invalid start number for hex format.",
					log_levels.ERROR,
					{ title = "Incrementing Visual Blocks" }
				)
				return
			end
		elseif format_type == "aa" or format_type == "aA" then
			if not start_char then -- Should be unreachable due to checks above
				notify(
					"Internal error: Start character not set for alphabet format.",
					log_levels.ERROR,
					{ title = "Incrementing Visual Blocks" }
				)
				return
			end
		end

		-- Ensure the current buffer (0) is valid before proceeding
		local current_buf = 0 -- Typically operates on the current buffer
		if not api.nvim_buf_is_valid(current_buf) then
			notify("Current buffer is not valid.", log_levels.ERROR, { title = "Incrementing Visual Blocks" })
			return
		end

		-- Get visual selection range
		local start_pos = fn.getpos("'<")
		local end_pos = fn.getpos("'>")

		-- Ensure visual selection marks are valid
		if start_pos[2] == 0 or end_pos[2] == 0 then
			notify("Invalid visual selection.", log_levels.ERROR, { title = "Incrementing Visual Blocks" })
			return
		end

		-- Ensure start is before end
		if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
			start_pos, end_pos = end_pos, start_pos
		end

		local start_row = start_pos[2]
		local start_col = start_pos[3]
		local end_row = end_pos[2]
		local end_col = end_pos[3]

		local current_number = start_number
		local current_char_byte = start_char and string_byte(start_char) or nil

		local max_byte = nil
		if format_type == "aa" then
			max_byte = string_byte("z")
		elseif format_type == "aA" then
			max_byte = string_byte("Z")
		end

		local new_lines = {}
		-- Get lines 0-indexed for API (already checked buffer validity)
		local original_lines = api.nvim_buf_get_lines(current_buf, start_row - 1, end_row, false)

		-- Iterate through lines in the visual block
		for i, line in ipairs(original_lines) do
			local prefix = ""
			local suffix = ""
			local block_width = 0

			-- Note: Using byte-based substring operations (string_sub).
			-- This is generally fine but might be inaccurate for calculating prefix/suffix
			-- lengths if multi-byte characters exist before the start_col.
			-- Handling this with full Unicode correctness significantly increases complexity.
			if start_col > 0 then
				prefix = string_sub(line, 1, start_col - 1)
			end
			local line_len = #line
			local effective_end_col = math_min(end_col, line_len)

			if effective_end_col >= start_col then
				block_width = effective_end_col - start_col + 1
			else
				block_width = 0
			end

			if effective_end_col < line_len then
				suffix = string_sub(line, effective_end_col + 1)
			end

			local value_str -- String representation of the number/char for the current line

			-- Generate the string based on the format
			if format_type == "h" then
				value_str = string_format("%x", current_number)
				current_number = current_number + 1
			elseif format_type == "d" then
				value_str = tostring(current_number)
				current_number = current_number + 1
			elseif format_type == "aa" or format_type == "aA" then
				if not current_char_byte then
					notify(
						"Internal error: character byte not set.",
						log_levels.ERROR,
						{ title = "Incrementing Visual Blocks" }
					)
					return -- Exit if internal state is wrong
				end

				if current_char_byte > max_byte then
					notify(
						"Maximum character reached ('" .. string_char(max_byte) .. "'). Stopping.",
						log_levels.WARN,
						{ title = "Incrementing Visual Blocks" }
					)
					goto apply_changes -- Stop processing but apply previous changes
				end

				value_str = string_char(current_char_byte)
				current_char_byte = current_char_byte + 1
			else
				-- This path should be unreachable due to prior validation
				notify(
					"Internal error: Unknown format type.",
					log_levels.ERROR,
					{ title = "Incrementing Visual Blocks" }
				)
				return
			end

			local padded_value_str = value_str
			if block_width > 0 then
				padded_value_str = string_format("%-" .. block_width .. "s", value_str) -- Left-align and pad
			else
				padded_value_str = value_str -- Avoid padding if width is zero/negative
			end

			local new_line = prefix .. padded_value_str .. suffix
			table_insert(new_lines, new_line)
		end

		::apply_changes::

		-- Apply changes only if there are lines to change and buffer is still valid
		if #new_lines > 0 then
			-- Re-check buffer validity just before writing for extra safety
			if not api.nvim_buf_is_valid(current_buf) then
				notify(
					"Buffer became invalid before changes could be applied.",
					log_levels.ERROR,
					{ title = "Incrementing Visual Blocks" }
				)
				return
			end
			cmd("undojoin") -- Group changes for a single undo
			api.nvim_buf_set_lines(current_buf, start_row - 1, start_row - 1 + #new_lines, false, new_lines)
			notify("Visual block numbering completed.", log_levels.INFO, { title = "Incrementing Visual Blocks" })
		else
			notify("No lines were modified.", log_levels.INFO, { title = "Incrementing Visual Blocks" })
		end
	end)
end

-- Setup function to create command and keymap
function M.setup()
	api.nvim_create_user_command("IncIndex", M.inc_index, {
		desc = "Number lines in visual block (d<num>, h<hex>, a<char>)",
		range = true,
	})

	vim.keymap.set("v", "<leader>ii", ":IncIndex<CR>", { desc = "Increment Index in Visual Block" })
end

return M
