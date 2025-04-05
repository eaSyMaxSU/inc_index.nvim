## Description
A really small neovim plugin for incrementing numbers (dec | hex), alphbets easier.
Trying to improve quality of life for an asic engineer, or others that may also need this.

Example config:

```
vim.keymap.set("v", "<leader>ic", ":IncIndex <CR>", { desc = "Blocks increment" })
```

To use this:
1. Enter visual block mode (Ctrl-v).
2. Select the rectangular block you want to increment.
3. Press <leader>ic (or the keymap you configured).
4. Enter the format and start number when prompted (e.g., h0, d11, aa, etc.).

