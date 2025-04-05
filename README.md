## Description
For incrementing numbers (dec | hex), alphbets easier, trying to improve quality of life for an asic engineering.

Example config:

```
vim.keymap.set("v", "<leader>ic", ":IncIndex <CR>", { desc = "Blocks increment" })
```

To use this:
1. Enter visual block mode (Ctrl-v).
2. Select the rectangular block you want to increment.
3. Press <leader>ic (or the keymap you configured).
4. Enter the format and start number when prompted (e.g., h0, d11, aa, etc.).

