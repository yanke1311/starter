require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map("n", "<F5>", "<cmd>CMakeRun<CR>", { desc = "cmake run" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "tab next" })
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "tab next" })

-- meno --
-- nvim-tree-lua
-- C-t open new tab
-- C-v open vertical
-- C-x open horizontal
--

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
