require "nvchad.mappings"

-- add yours here

-- 终端里 <Tab> 和 <C-i> 是同一个键；NvChad 用 Tab 切 buffer 会抢走 jumplist 前进。
-- 切 buffer 用下面的 Shift-h / Shift-l。
pcall(vim.keymap.del, "n", "<tab>")

local map = vim.keymap.set

-- 叠在 NvChad 的 noh 上：有鼠标 hover 浮窗时 Esc 一并关掉。
map("n", "<Esc>", function()
  vim.cmd.nohlsearch()
  require("configs.lsp_mouse_hover").dismiss()
end, { desc = "Clear highlights and hover" })

-- 不要映射 n 模式的 `;` → `:`，否则会抢走 f/t/F/T 之后的 `;` 重复、`/` 反向重复。
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
map({ "n", "v" }, "<leader>cM", function()
  require("configs.codebuddy").select_model()
end, { desc = "CodeBuddy 切换模型" })
map({ "n", "v" }, "<leader>cP", function()
  require("configs.codebuddy").select_mode()
end, { desc = "CodeBuddy 切换模式" })

local function visual_star(backward)
  vim.cmd 'normal! "vy'
  local pat = [[\V]] .. vim.fn.escape(vim.fn.getreg "v", [[\]]):gsub("\n", [[\n]])
  vim.fn.setreg("/", pat)
  vim.v.searchforward = backward and 0 or 1
  vim.cmd("normal! " .. (backward and "N" or "n"))
  vim.opt.hlsearch = true
end

map("x", "*", function()
  visual_star(false)
end, { desc = "Search selection" })
map("x", "#", function()
  visual_star(true)
end, { desc = "Search selection backward" })

-- NvChad 默认 <C-l> 是切右侧窗口；改成清屏：关掉 */#// 高亮并 redraw。
-- 切窗仍用 <C-w>l。
map("n", "<C-l>", "<cmd>nohlsearch<CR><C-l>", { desc = "Clear search highlight" })

-- 对齐 VSCodeVim / scopelet
map("n", "<leader>ff", function()
  require("configs.search").find_files()
end, { desc = "telescope find files" })
map("n", "<leader>fg", function()
  require("configs.search").live_grep()
end, { desc = "telescope live grep" })
map("n", "<leader>fH", function()
  require("configs.search").prompt_history()
end, { desc = "telescope prompt history" })
map("n", "<leader>fw", "<cmd>Telescope lsp_references<CR>", { desc = "telescope LSP references" })
map("n", "<leader>fs", "<cmd>Telescope lsp_document_symbols<CR>", { desc = "telescope document symbols" })
map("n", "<leader>ma", "<cmd>Telescope marks<CR>", { desc = "telescope marks" })
map("n", "<leader>fG", function()
  require("configs.search").live_grep {
    default_text = vim.fn.expand "<cword>",
    literal = true,
  }
end, { desc = "telescope grep word" })
map("v", "<leader>fG", function()
  local mode = vim.fn.mode()
  local text = table.concat(vim.fn.getregion(vim.fn.getpos "v", vim.fn.getpos ".", { type = mode }), "\n")
  require("configs.search").live_grep {
    default_text = vim.trim(text),
    literal = true,
  }
end, { desc = "telescope grep selection" })
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

local gitdiff = require "configs.gitdiff"

local function close_gitsigns_diff()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
    if name:find("^gitsigns://", 1) then
      pcall(vim.api.nvim_win_close, win, false)
    else
      gitdiff.clear_win(win)
    end
  end
  vim.cmd.diffoff()
end

-- gitsigns 关掉对侧窗口时，BufHidden 里对侧仍在且 diff=true，本窗口会卡在 diff 模式。
map("n", "<leader>gd", function()
  if vim.wo.diff then
    close_gitsigns_diff()
    return
  end
  require("gitsigns").diffthis()
  vim.schedule(gitdiff.style_windows)
end, { desc = "Git diff this" })

vim.api.nvim_create_autocmd("WinClosed", {
  group = vim.api.nvim_create_augroup("gitsigns_diffoff", { clear = true }),
  callback = function()
    vim.schedule(function()
      local win = vim.api.nvim_get_current_win()
      if not vim.api.nvim_win_is_valid(win) or not vim.wo[win].diff then
        return
      end
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if w ~= win and vim.wo[w].diff then
          return
        end
      end
      gitdiff.clear_win(win)
      vim.cmd.diffoff()
    end)
  end,
})

map("n", "<leader>gq", function()
  require("gitsigns").setqflist()
end, { desc = "Git hunks to quickfix" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
