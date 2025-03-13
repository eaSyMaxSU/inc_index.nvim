Keymap to trigger the function in visual mode (block visual mode Ctrl-v)
vim.keymap.set("v", "<leader>ic", ":lua visual_block_numbering()<CR>", { desc = "Block Numbering" })

Example usage comment (for documentation in your config file)
To use this:
1. Enter visual block mode (Ctrl-v).
2. Select the rectangular block you want to number.
3. Press <leader>ic (or the keymap you configured).
4. Enter the format and start number when prompted (e.g., h0, d11, 5, etc.).

