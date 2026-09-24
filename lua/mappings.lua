require "nvchad.mappings"

-- add yours here

-- 终端里 <Tab> 和 <C-i> 是同一个键；NvChad 用 Tab 切 buffer 会抢走 jumplist 前进。
-- 切 buffer 用下面的 Shift-h / Shift-l。
pcall(vim.keymap.del, "n", "<tab>")

local map = vim.keymap.set

local function cmake_terminal_wins()
  local wins = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "cmake_tools_terminal" or vim.bo[buf].buftype == "terminal" and vim.api.nvim_buf_get_name(buf):find("CMakeTools", 1, true) then
      wins[#wins + 1] = win
    end
  end
  return wins
end

local function toggle_horizontal_term()
  local cmake_wins = cmake_terminal_wins()
  if #cmake_wins > 0 then
    for _, win in ipairs(cmake_wins) do
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, false)
      end
    end
    return
  end
  require("nvchad.term").toggle { pos = "sp", id = "htoggleTerm" }
end

local function toggle_float_term()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm", winopts = { winblend = 20 } }
end

map({ "n", "t" }, "<C-`>", toggle_horizontal_term, { desc = "Toggle horizontal terminal" })
map("n", "<leader>tt", toggle_horizontal_term, { desc = "Toggle horizontal terminal" })
map({ "n", "t" }, "<A-i>", toggle_float_term, { desc = "Toggle floating terminal" })
map("n", "<leader>tf", toggle_float_term, { desc = "Toggle floating terminal" })

-- 叠在 NvChad 的 noh 上：有鼠标 hover 浮窗时 Esc 一并关掉。
map("n", "<Esc>", function()
  vim.cmd.nohlsearch()
  require("configs.lsp_mouse_hover").dismiss()
end, { desc = "Clear highlights and hover" })

-- 不要映射 n 模式的 `;` → `:`，否则会抢走 f/t/F/T 之后的 `;` 重复、`/` 反向重复。
map("i", "jk", "<ESC>")

-- 调试/运行快捷键统一由 configs.dap.keys 声明。
map("n", "<S-l>", function()
  require("nvchad.tabufline").next()
end, { desc = "tab next" })
map("n", "<S-h>", function()
  require("nvchad.tabufline").prev()
end, { desc = "tab prev" })

-- ,x 关的是标签栏里的一个 buffer。Diffview 这类占的是整个标签页。
map("n", "<leader>X", function()
  if vim.fn.tabpagenr "$" > 1 then
    vim.cmd.tabclose()
  end
end, { desc = "close tab" })

-- meno --
-- nvim-tree-lua
-- C-t open new tab
-- C-v open vertical
-- C-x open horizontal
map("n", "<M-n>", "<cmd>NvimTreeToggle<CR>", { desc = "NvimTreeToggle" })
map("n", "<Leader>q", "<cmd>cclose<CR><cmd>lclose<CR>", { desc = "close quickfix window" })
map("n", "<leader>cl", vim.lsp.codelens.run, { desc = "Run CodeLens" })

local function visual_star(backward)
  vim.cmd 'normal! "vy'
  local pat = [[\V]] .. vim.fn.escape(vim.fn.getreg "v", [[\]]):gsub("\n", [[\n]])
  vim.fn.setreg("/", pat)
  vim.v.searchforward = backward and 0 or 1
  vim.cmd "normal! n" -- searchforward 已决定方向，N 会再次反转。
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
map("n", "<leader>fp", function()
  require("configs.search").projects()
end, { desc = "telescope projects" })
map("n", "<leader>fu", "<cmd>Telescope undo<CR>", { desc = "telescope undo" })
map("n", "<leader>fj", "<cmd>Telescope jumplist<CR>", { desc = "telescope jumplist" })
map("n", "<leader>fd", function()
  require("configs.feed").pick_source()
end, { desc = "feed news" })
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
-- gitsigns 不再默认映射 ]c/[c。普通 buffer 里它们是 Vim 的 diff 跳转，没有 diff 时没有效果。
local function hunk_nav(dir, diff_key)
  return function()
    if vim.wo.diff then
      vim.cmd.normal { diff_key, bang = true }
      return
    end
    require("gitsigns").nav_hunk(dir)
  end
end

map("n", "]c", hunk_nav("next", "]c"), { desc = "Git next hunk" })
map("n", "[c", hunk_nav("prev", "[c"), { desc = "Git prev hunk" })
map("n", "]h", hunk_nav("next", "]c"), { desc = "Git next hunk" })
map("n", "[h", hunk_nav("prev", "[c"), { desc = "Git prev hunk" })

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

map("n", "<leader>gR", function()
  require("configs.search").git_repos()
end, { desc = "Git repos under cwd" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
