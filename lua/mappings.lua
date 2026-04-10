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
map("n", "<M-n>", "<cmd>NvimTreeToggle<CR>", { desc = "NvimTreeToggle" })
map("n", "<Leader>q", "<cmd>cclose<CR><cmd>lclose<CR>", { desc = "close quickfix window" })
map("n", "<leader>cl", vim.lsp.codelens.run, { desc = "Run CodeLens" })
--gitsigns--
map("n", "]h", function()
  require("gitsigns").nav_hunk "next"
end, { desc = "Git next hunk" })

map("n", "[h", function()
  require("gitsigns").nav_hunk "prev"
end, { desc = "Git prev hunk" })

map("n", "<leader>gp", function()
  require("gitsigns").preview_hunk()
end, { desc = "Git preview hunk" })

-- map("n", "<leader>gs", function()
--   require("gitsigns").stage_hunk()
-- end, { desc = "Git stage hunk" })

map("n", "<leader>gr", function()
  require("gitsigns").reset_hunk()
end, { desc = "Git reset hunk" })

map("n", "<leader>gb", function()
  require("gitsigns").blame_line()
end, { desc = "Git blame line" })

map("n", "<leader>gB", "<cmd>Gitsigns toggle_current_line_blame<CR>", { desc = "Git toggle line blame" })

map("n", "<leader>gd", function()
  require("gitsigns").diffthis()
end, { desc = "Git diff this" })

map("n", "<leader>gq", function()
  require("gitsigns").setqflist()
end, { desc = "Git hunks to quickfix" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
