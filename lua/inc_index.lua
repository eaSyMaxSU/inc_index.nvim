-- Localize Neovim API and Lua functions for performance and clarity
local M = {}

local api = vim.api
local fn = vim.fn
local ui = vim.ui
local notify = vim.notify
local log_levels = vim.log.levels -- Cache log levels
-- local cmd = vim.cmd -- cmd is no longer used

-- Cache string and math functions
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

			if string_match(input_value_str, "%l") then -- Check for lowercase letter
				format_type = "aa"
			elseif string_match(input_value_str, "%u") then -- Check for uppercase letter
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
			-- Default to decimal if no specific format character is provided
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
					"Invalid start number for decimal format. Must be a number.",
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
			start_number = tonumber(input_value_str, 16) -- Base 16 for hexadecimal
			if not start_number then
				notify(
					"Invalid start number for hex format. Must be a valid hexadecimal number.",
					log_levels.ERROR,
					{ title = "Incrementing Visual Blocks" }
				)
				return
			end
		elseif format_type == "aa" or format_type == "aA" then
			-- start_char is already validated and set at this point
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
		local current_buf = 0 -- Operates on the current buffer
		if not api.nvim_buf_is_valid(current_buf) then
			notify("Current buffer is not valid.", log_levels.ERROR, { title = "Incrementing Visual Blocks" })
			return
		end

		-- Get visual selection range
		-- fn.getpos("'<") returns a list: [bufnum, lnum, col, off]
		local start_pos = fn.getpos("'<")
		local end_pos = fn.getpos("'>")

		-- Ensure visual selection marks are valid (lnum > 0)
		if start_pos[2] == 0 or end_pos[2] == 0 then
			notify(
				"Invalid visual selection. Please make a visual selection first.",
				log_levels.ERROR,
				{ title = "Incrementing Visual Blocks" }
			)
			return
		end

		-- Ensure start is before end (handles cases where selection is made upwards)
		if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
			start_pos, end_pos = end_pos, start_pos -- Swap them
		end

		local start_row = start_pos[2] -- 1-indexed line number
		local start_col = start_pos[3] -- 1-indexed byte column
		local end_row = end_pos[2] -- 1-indexed line number
		local end_col = end_pos[3] -- 1-indexed byte column

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
			local current_line_nr = start_row - 1 + i -- 0-indexed line number for API, 1-indexed for user
			local prefix = ""
			local suffix = ""
			local block_width = 0

			-- Determine the actual start and end columns for this specific line
			-- in a block selection. For non-block selections, it's simpler.
			-- For simplicity, this script assumes block selection behavior for column interpretation.
			local current_line_start_col = start_col
			local current_line_end_col = end_col

			-- Note: Using byte-based substring operations (string_sub).
			-- This is generally fine but might be inaccurate for calculating prefix/suffix
			-- lengths if multi-byte characters exist before the start_col.
			-- Handling this with full Unicode correctness significantly increases complexity.
			if current_line_start_col > 1 then -- Columns are 1-indexed
				prefix = string_sub(line, 1, current_line_start_col - 1)
			end

			local line_len_bytes = #line
			local effective_end_col_on_line = math_min(current_line_end_col, line_len_bytes)

			if effective_end_col_on_line >= current_line_start_col then
				block_width = effective_end_col_on_line - current_line_start_col + 1
			else
				-- This can happen if the visual block selection extends beyond the line length
				-- or if start_col is beyond line length.
				block_width = 0
			end

			if effective_end_col_on_line < line_len_bytes then
				suffix = string_sub(line, effective_end_col_on_line + 1)
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
						"Internal error: character byte not set for alphabet format.",
						log_levels.ERROR,
						{ title = "Incrementing Visual Blocks" }
					)
					return -- Exit if internal state is wrong
				end

				if current_char_byte > max_byte then
					notify(
						"Maximum character reached ('"
							.. string_char(max_byte)
							.. "'). Stopping generation for subsequent lines.",
						log_levels.WARN,
						{ title = "Incrementing Visual Blocks" }
					)
					-- Instead of goto, we can just use the value from the previous iteration or an empty string
					-- For now, let's make it stop adding new numbers but still process lines to keep structure
					value_str = "..." -- Placeholder or could be empty
					-- Or, we could break the loop if we don't want to process further lines at all.
					-- Using goto here was to apply changes made so far.
					-- Let's replicate that by just not updating value_str and letting the loop finish.
					-- For simplicity, we'll just use the last valid char or a placeholder.
					-- To truly stop incrementing, we'd need a flag.
					-- The original goto jumped to apply_changes. Here, we'll let it fall through.
					-- The notification is the main indicator.
					-- To prevent further increments, we can ensure current_char_byte doesn't change.
					-- However, the original code would still pad this "last" character.
					-- Let's stick to the warning and let it pad the last valid char.
					current_char_byte = current_char_byte - 1 -- revert the next increment
					value_str = string_char(current_char_byte) -- use the max char
					current_char_byte = current_char_byte + 1 -- then increment for the next line (which will also be over max)

					-- A better way to handle "stop generating":
					-- Set a flag and check it.
					-- if not stop_generating then value_str = string_char(current_char_byte); current_char_byte = current_char_byte + 1 else value_str = "" end
					-- For now, let's keep it simple and just warn. The original goto was a bit abrupt.
					-- The problem with goto is that it makes the flow harder to follow.
					-- Let's assume if max_byte is hit, we just reuse the max_byte character.
					value_str = string_char(max_byte)
					-- We do not increment current_char_byte further if it's already at max_byte to avoid overflow issues
					-- This means subsequent lines will get the same max character.
				else
					value_str = string_char(current_char_byte)
					current_char_byte = current_char_byte + 1
				end
			else
				-- This path should be unreachable due to prior validation
				notify(
					"Internal error: Unknown format type encountered during processing.",
					log_levels.ERROR,
					{ title = "Incrementing Visual Blocks" }
				)
				return
			end

			local padded_value_str
			if block_width > 0 then
				-- Ensure the value_str itself doesn't exceed block_width before padding
				local value_to_pad = string_sub(value_str, 1, block_width)
				padded_value_str = string_format("%-" .. block_width .. "s", value_to_pad) -- Left-align and pad/truncate
			else
				padded_value_str = "" -- If block width is zero, replace with empty (or could be value_str if preferred)
			end

			local new_line = prefix .. padded_value_str .. suffix
			table_insert(new_lines, new_line)
		end

		-- ::apply_changes:: -- This label was for the goto, which is now handled differently for char overflow

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
			-- cmd("undojoin") -- REMOVED: Group changes for a single undo. nvim_buf_set_lines should handle this.
			api.nvim_buf_set_lines(current_buf, start_row - 1, start_row - 1 + #new_lines, false, new_lines)
			notify("Visual block numbering completed.", log_levels.INFO, { title = "Incrementing Visual Blocks" })
		else
			notify(
				"No lines were modified (e.g., empty selection or no valid range).",
				log_levels.INFO,
				{ title = "Incrementing Visual Blocks" }
			)
		end
	end)
end

-- Setup function to create command and keymap
function M.setup()
	api.nvim_create_user_command("IncIndex", M.inc_index, {
		desc = "Number lines in visual block (d<num>, h<hex>, a<char>)",
		range = true, -- Indicates the command works with a range (visual selection)
	})

	-- Set keymap for visual mode
	-- <leader>ii will trigger the IncIndex command
	vim.keymap.set(
		"v",
		"<leader>ii",
		":IncIndex<CR>",
		{ desc = "Increment Index in Visual Block", noremap = true, silent = true }
	)
end

return M
