-- 把当前目录当 buffer 改：改名、新建、删除、挪文件，`:w` 生效。
-- 不替换 nvim-tree，只在 `-` 打开。

local M = {}

function M.opts()
  return {
    default_file_explorer = false,
    delete_to_trash = true,
    skip_confirm_for_simple_edits = true,
    watch_for_changes = true,
    view_options = { show_hidden = true },
    keymaps = {
      ["q"] = { "actions.close", mode = "n" },
      -- 让出 NvChad 的窗口切换 / 保存
      ["<C-h>"] = false,
      ["<C-l>"] = false,
      ["<C-s>"] = false,
    },
  }
end

function M.keys()
  return {
    {
      "-",
      "<cmd>Oil<cr>",
      desc = "Oil 打开当前目录",
    },
  }
end

return M
