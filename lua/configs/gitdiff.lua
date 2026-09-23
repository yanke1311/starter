-- 让 gitsigns :diffthis 更接近 VS Code 并排 diff：
-- 旧侧浅红底 + 改动处深红；新侧浅绿底 + 改动处深绿；保留语法色；少折叠。

local M = {}

function M.apply_highlights()
  local ok, base46 = pcall(require, "base46")
  if not ok then
    return
  end
  local colors = base46.get_theme_tb "base_30"
  local mix = require("base46.colors").mix
  -- 不设 fg，treesitter / markid 还能透出来，像 VS Code
  vim.api.nvim_set_hl(0, "DiffAdd", { bg = mix(colors.green, colors.black, 88) })
  vim.api.nvim_set_hl(0, "DiffDelete", { bg = mix(colors.red, colors.black, 88) })
  vim.api.nvim_set_hl(0, "GitDiffAddText", { bg = mix(colors.green, colors.black, 70) })
  vim.api.nvim_set_hl(0, "GitDiffDeleteText", { bg = mix(colors.red, colors.black, 70) })
end

function M.style_windows()
  M.apply_highlights()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.wo[win].diff then
      vim.wo[win].foldenable = false
      local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
      if name:find("^gitsigns://", 1) then
        vim.wo[win].winhighlight = "DiffChange:DiffDelete,DiffText:GitDiffDeleteText"
      else
        vim.wo[win].winhighlight = "DiffChange:DiffAdd,DiffText:GitDiffAddText"
      end
    end
  end
end

function M.clear_win(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.wo[win].winhighlight = ""
    vim.wo[win].foldenable = true
  end
end

function M.setup()
  vim.opt.diffopt:append "algorithm:histogram"
  vim.opt.diffopt:append "context:999"
  vim.opt.fillchars:append { diff = " " }

  M.apply_highlights()

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("gitdiff_hls", { clear = true }),
    callback = function()
      vim.schedule(M.apply_highlights)
    end,
  })

  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = vim.api.nvim_create_augroup("gitdiff_style", { clear = true }),
    pattern = "gitsigns://*",
    callback = function()
      vim.schedule(M.style_windows)
    end,
  })
end

return M
