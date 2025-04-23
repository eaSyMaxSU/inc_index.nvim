# IncIndex.nvim

A lightweight Neovim plugin for easily incrementing numbers (decimal, hexadecimal) or characters (alphabetical) within visual block selections.

Designed to improve quality of life, especially for tasks involving repetitive numbering or labeling (e.g., signal lists, register maps).

## ✨ Features
- Increment numbers: Supports decimal (d) and hexadecimal (h) formats.
- Increment characters: Supports lowercase (a to z) and uppercase (A to Z) alphabetical sequences. Case is automatically detected based on the starting character provided.
- Visual Block Mode: Operates specifically on text selected in Visual Block mode (Ctrl-V).
- Flexible Starting Point: Specify the exact number or character to start incrementing from.
- Simple Command: Uses a single command :IncIndex which prompts for input.

## 💾 Installation
Using lazy.nvim
```
{
  "eaSyMaxSU/inc-index.nvim",
  config = function()
    require("inc_index").setup()
  end,
}
```

## ⚙️ Configuration
The plugin needs to be set up.
```
-- Load the setup function (required for both installation methods)
require("inc_index").setup()


-- Example custom keymap (optional, the setup function creates the command)
-- The default command is :IncIndex
vim.keymap.set("v", "<leader>ic", ":IncIndex<CR>", { desc = "Increment Index in Visual Block" })
-- Or map it to something else:
-- vim.keymap.set("v", "<leader>ii", ":IncIndex<CR>", { desc = "Increment Index" })
```

## 🚀 Usage
Enter Visual Block Mode: Press Ctrl-V.

Select Block: Select the rectangular block of text across multiple lines where you want the incrementing values to appear. The width of the selection matters, as the generated number/character will be padded to fit this width.

Run Command: Press your configured keymap (e.g., <leader>ic) or manually type :IncIndex<CR>.

Enter Format & Start Value: You will be prompted to enter the format and starting value.

Use one of the following formats:
- d<number>: Start incrementing with a decimal number (e.g., d1, d0, d100).
- h<hex_number>: Start incrementing with a hexadecimal number (e.g., h0, hA, h1f).
- a<character>: Start incrementing alphabetically from the given character. Case determines the sequence (e.g., ac starts c, d, e..., aC starts C, D, E...). (Note: The sequence stops at 'z' or 'Z')

Press Enter: The selected block will be replaced with the incrementing sequence.

