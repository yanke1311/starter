require "nvchad.options"

-- add yours here!

-- local o = vim.o
-- o.cursorlineopt ='both' -- to enable cursorline!
--
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
-- vim.opt.cursorline = true
-- vim.opt.cursorcolumn = true

local autocmd = vim.api.nvim_create_autocmd

autocmd("BufReadPost", {
  pattern = "*",
  callback = function()
    local line = vim.fn.line "'\""
    if
      line > 1
      and line <= vim.fn.line "$"
      and vim.bo.filetype ~= "commit"
      and vim.fn.index({ "xxd", "gitrebase" }, vim.bo.filetype) == -1
    then
      vim.cmd 'normal! g`"'
    end
  end,
})

vim.api.nvim_create_autocmd("BufDelete", {
  callback = function()
    local bufs = vim.t.bufs
    if #bufs == 1 and vim.api.nvim_buf_get_name(bufs[1]) == "" then
      vim.cmd "Nvdash"
    end
  end,
})

-- 用于lsp查询，效果是对于grr的所有使用到的地方，在quickfix窗口实现类似vscode一样的预览
-- 第一版
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = "qf",
--   callback = function(args)
--     local opts = { buffer = args.buf, silent = true }
--     vim.keymap.set("n", "j", "j<CR><C-w>p", opts)
--     vim.keymap.set("n", "k", "k<CR><C-w>p", opts)
--     vim.keymap.set("n", "<CR>", "<CR>:cclose<CR>", opts)
--   end,
-- })

-- 第二版,增加了窗口预览，行高亮，以及始终在主窗口中间
-- local qf_preview_ns = vim.api.nvim_create_namespace("qf_preview_ns")
-- local qf_preview_group = vim.api.nvim_create_augroup("qf_preview_follow", { clear = true })
--
-- local qf_state = {
--   preview_win = nil,
-- }
--
-- local function clear_all_qf_preview_highlight()
--   for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
--     if vim.api.nvim_buf_is_valid(bufnr) then
--       pcall(vim.api.nvim_buf_clear_namespace, bufnr, qf_preview_ns, 0, -1)
--     end
--   end
-- end
--
-- local function get_qf_win()
--   local info = vim.fn.getqflist({ winid = 0 })
--   return info.winid ~= 0 and info.winid or nil
-- end
--
-- local function resolve_preview_win()
--   local qf_win = get_qf_win()
--
--   if qf_state.preview_win
--     and vim.api.nvim_win_is_valid(qf_state.preview_win)
--     and qf_state.preview_win ~= qf_win
--   then
--     return qf_state.preview_win
--   end
--
--   local alt_win = vim.fn.win_getid(vim.fn.winnr("#"))
--   if alt_win ~= 0
--     and vim.api.nvim_win_is_valid(alt_win)
--     and alt_win ~= qf_win
--   then
--     qf_state.preview_win = alt_win
--     return alt_win
--   end
--
--   for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
--     if win ~= qf_win then
--       qf_state.preview_win = win
--       return win
--     end
--   end
--
--   return nil
-- end
--
-- local function get_current_qf_item()
--   local info = vim.fn.getqflist({ items = 0 })
--   local items = info.items or {}
--
--   local line_nr = vim.fn.line(".")
--   local item = items[line_nr]
--
--   if not item or not item.bufnr or item.bufnr == 0 then
--     return nil
--   end
--
--   return item
-- end
--
-- local function preview_qf_item()
--   local item = get_current_qf_item()
--   if not item then
--     return
--   end
--
--   local preview_win = resolve_preview_win()
--   if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
--     return
--   end
--
--   local bufnr = item.bufnr
--   local lnum = (item.lnum and item.lnum > 0) and item.lnum or 1
--   local col = (item.col and item.col > 0) and (item.col - 1) or 0
--
--   vim.api.nvim_win_set_buf(preview_win, bufnr)
--   vim.api.nvim_win_set_cursor(preview_win, { lnum, col })
--
--   vim.api.nvim_win_call(preview_win, function()
--     vim.cmd("normal! zz")
--   end)
--
--   clear_all_qf_preview_highlight()
--
--   vim.api.nvim_buf_set_extmark(bufnr, qf_preview_ns, lnum - 1, 0, {
--     line_hl_group = "Visual",
--     priority = 200,
--   })
-- end
--
-- local function confirm_qf_item_and_close()
--   local item = get_current_qf_item()
--   if not item then
--     return
--   end
--
--   local preview_win = resolve_preview_win()
--   if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
--     return
--   end
--
--   vim.cmd("cclose")
--
--   local lnum = (item.lnum and item.lnum > 0) and item.lnum or 1
--   local col = (item.col and item.col > 0) and (item.col - 1) or 0
--
--   vim.api.nvim_set_current_win(preview_win)
--   vim.api.nvim_win_set_buf(preview_win, item.bufnr)
--   vim.api.nvim_win_set_cursor(preview_win, { lnum, col })
--   vim.cmd("normal! zz")
--
--   clear_all_qf_preview_highlight()
-- end
--
-- vim.api.nvim_create_autocmd("FileType", {
--   group = qf_preview_group,
--   pattern = "qf",
--   callback = function(args)
--     local qf_buf = args.buf
--     qf_state.preview_win = resolve_preview_win()
--
--     local opts = { buffer = qf_buf, silent = true, noremap = true, nowait = true }
--
--     local function move_and_preview(key)
--       return function()
--         vim.cmd("normal! " .. key)
--         preview_qf_item()
--       end
--     end
--
--     vim.keymap.set("n", "j", move_and_preview("j"), opts)
--     vim.keymap.set("n", "k", move_and_preview("k"), opts)
--     vim.keymap.set("n", "<Down>", move_and_preview("j"), opts)
--     vim.keymap.set("n", "<Up>", move_and_preview("k"), opts)
--
--     vim.keymap.set("n", "<CR>", confirm_qf_item_and_close, opts)
--
--     vim.keymap.set("n", "q", function()
--       vim.cmd("cclose")
--       clear_all_qf_preview_highlight()
--     end, opts)
--
--     vim.schedule(function()
--       if vim.api.nvim_buf_is_valid(qf_buf) then
--         preview_qf_item()
--       end
--     end)
--   end,
-- })
--
-- vim.api.nvim_create_autocmd("BufWinLeave", {
--   group = qf_preview_group,
--   pattern = "*",
--   callback = function()
--     local qf_win = get_qf_win()
--     if not qf_win then
--       clear_all_qf_preview_highlight()
--     end
--   end,
-- })

-- 第三版, 增加高亮
local qf_preview_ns = vim.api.nvim_create_namespace("qf_preview_ns")
local qf_preview_group = vim.api.nvim_create_augroup("qf_preview_follow", { clear = true })

local qf_state = {
  preview_win = nil,
  symbol = nil,
  qf_match_id = nil,
  preview_match_id = nil,
  preview_match_win = nil,
}

local function clear_all_qf_preview_highlight()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, qf_preview_ns, 0, -1)
    end
  end
end

local function get_qf_win()
  local info = vim.fn.getqflist({ winid = 0 })
  return info.winid ~= 0 and info.winid or nil
end

local function resolve_preview_win()
  local qf_win = get_qf_win()

  if qf_state.preview_win
    and vim.api.nvim_win_is_valid(qf_state.preview_win)
    and qf_state.preview_win ~= qf_win
  then
    return qf_state.preview_win
  end

  local alt_win = vim.fn.win_getid(vim.fn.winnr("#"))
  if alt_win ~= 0
    and vim.api.nvim_win_is_valid(alt_win)
    and alt_win ~= qf_win
  then
    qf_state.preview_win = alt_win
    return alt_win
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= qf_win then
      qf_state.preview_win = win
      return win
    end
  end

  return nil
end

local function get_symbol_from_win(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return nil
  end

  local ok, symbol = pcall(vim.api.nvim_win_call, win, function()
    return vim.fn.expand("<cword>")
  end)

  if ok and symbol and symbol ~= "" then
    return symbol
  end

  return nil
end

local function clear_symbol_matches()
  local qf_win = get_qf_win()

  if qf_state.qf_match_id and qf_win and vim.api.nvim_win_is_valid(qf_win) then
    pcall(vim.fn.matchdelete, qf_state.qf_match_id, qf_win)
  end
  qf_state.qf_match_id = nil

  if qf_state.preview_match_id
    and qf_state.preview_match_win
    and vim.api.nvim_win_is_valid(qf_state.preview_match_win)
  then
    pcall(vim.fn.matchdelete, qf_state.preview_match_id, qf_state.preview_match_win)
  end
  qf_state.preview_match_id = nil
  qf_state.preview_match_win = nil
end

local function add_symbol_match_to_win(win, symbol, hl)
  if not win or not vim.api.nvim_win_is_valid(win) or not symbol or symbol == "" then
    return nil
  end

  local pattern = [[\V\<]] .. vim.fn.escape(symbol, [[\]]) .. [[\>]]

  local ok, match_id = pcall(vim.api.nvim_win_call, win, function()
    return vim.fn.matchadd(hl or "Search", pattern, 20)
  end)

  if ok then
    return match_id
  end

  return nil
end

local function refresh_symbol_matches()
  clear_symbol_matches()

  local symbol = qf_state.symbol
  if not symbol or symbol == "" then
    return
  end

  local qf_win = get_qf_win()
  local preview_win = resolve_preview_win()

  qf_state.qf_match_id = add_symbol_match_to_win(qf_win, symbol, "Search")

  if preview_win then
    qf_state.preview_match_id = add_symbol_match_to_win(preview_win, symbol, "Search")
    qf_state.preview_match_win = preview_win
  end
end

local function get_current_qf_item()
  local info = vim.fn.getqflist({ items = 0 })
  local items = info.items or {}

  local line_nr = vim.fn.line(".")
  local item = items[line_nr]

  if not item or not item.bufnr or item.bufnr == 0 then
    return nil
  end

  return item
end

local function preview_qf_item()
  local item = get_current_qf_item()
  if not item then
    return
  end

  local preview_win = resolve_preview_win()
  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
    return
  end

  local bufnr = item.bufnr
  local lnum = (item.lnum and item.lnum > 0) and item.lnum or 1
  local col = (item.col and item.col > 0) and (item.col - 1) or 0

  vim.api.nvim_win_set_buf(preview_win, bufnr)
  vim.api.nvim_win_set_cursor(preview_win, { lnum, col })

  vim.api.nvim_win_call(preview_win, function()
    vim.cmd("normal! zz")
  end)

  clear_all_qf_preview_highlight()

  vim.api.nvim_buf_set_extmark(bufnr, qf_preview_ns, lnum - 1, 0, {
    line_hl_group = "Visual",
    priority = 200,
  })

  refresh_symbol_matches()
end

local function confirm_qf_item_and_close()
  local item = get_current_qf_item()
  if not item then
    return
  end

  local preview_win = resolve_preview_win()
  if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
    return
  end

  vim.cmd("cclose")

  local lnum = (item.lnum and item.lnum > 0) and item.lnum or 1
  local col = (item.col and item.col > 0) and (item.col - 1) or 0

  vim.api.nvim_set_current_win(preview_win)
  vim.api.nvim_win_set_buf(preview_win, item.bufnr)
  vim.api.nvim_win_set_cursor(preview_win, { lnum, col })
  vim.cmd("normal! zz")

  clear_all_qf_preview_highlight()
  clear_symbol_matches()
end

-- lsp hover
vim.opt.updatetime = 500
vim.opt.mouse = "a"

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local bufnr = args.buf

    vim.keymap.set("n", "K", vim.lsp.buf.hover, {
      buffer = bufnr,
      desc = "LSP Hover",
    })

    vim.keymap.set("n", "<leader>k", vim.lsp.buf.signature_help, {
      buffer = bufnr,
      desc = "Signature Help",
    })

    vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, {
      buffer = bufnr,
      desc = "Signature Help",
    })

    vim.api.nvim_create_autocmd("CursorHold", {
      buffer = bufnr,
      callback = function()
        vim.lsp.buf.hover()
      end,
    })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = qf_preview_group,
  pattern = "qf",
  callback = function(args)
    local qf_buf = args.buf
    qf_state.preview_win = resolve_preview_win()
    qf_state.symbol = get_symbol_from_win(qf_state.preview_win)

    local opts = { buffer = qf_buf, silent = true, noremap = true, nowait = true }

    local function move_and_preview(key)
      return function()
        vim.cmd("normal! " .. key)
        preview_qf_item()
      end
    end

    vim.keymap.set("n", "j", move_and_preview("j"), opts)
    vim.keymap.set("n", "k", move_and_preview("k"), opts)
    vim.keymap.set("n", "<Down>", move_and_preview("j"), opts)
    vim.keymap.set("n", "<Up>", move_and_preview("k"), opts)

    vim.keymap.set("n", "<CR>", confirm_qf_item_and_close, opts)

    vim.keymap.set("n", "q", function()
      vim.cmd("cclose")
      clear_all_qf_preview_highlight()
      clear_symbol_matches()
    end, opts)

    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(qf_buf) then
        preview_qf_item()
      end
    end)
  end,
})

vim.api.nvim_create_autocmd("BufWinLeave", {
  group = qf_preview_group,
  pattern = "*",
  callback = function()
    local qf_win = get_qf_win()
    if not qf_win then
      clear_all_qf_preview_highlight()
      clear_symbol_matches()
    end
  end,
})


-- 用于lsp的lens
vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
  callback = function(args)
    local bufnr = args.buf
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
      if client.server_capabilities.codeLensProvider then
        vim.lsp.codelens.refresh({ bufnr = bufnr })
        return
      end
    end
  end,
})

-- cmake tools
local osys = require("cmake-tools.osys")
require("cmake-tools").setup {
  cmake_command = "cmake", -- this is used to specify cmake command path
  ctest_command = "ctest", -- this is used to specify ctest command path
  cmake_use_preset = true,
  cmake_regenerate_on_save = true, -- auto generate when save CMakeLists.txt
  cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" }, -- this will be passed when invoke `CMakeGenerate`
  cmake_build_options = {}, -- this will be passed when invoke `CMakeBuild`
  -- support macro expansion:
  --       ${kit}
  --       ${kitGenerator}
  --       ${variant:xx}
  cmake_build_directory = function()
    if osys.iswin32 then
      return "out\\${variant:buildType}"
    end
    return "out/${variant:buildType}"
  end, -- this is used to specify generate directory for cmake, allows macro expansion, can be a string or a function returning the string, relative to cwd.
  cmake_compile_commands_options = {
    action = "soft_link", -- available options: soft_link, copy, lsp, none
                          -- soft_link: this will automatically make a soft link from compile commands file to target
                          -- copy:      this will automatically copy compile commands file to target
                          -- lsp:       this will automatically set compile commands file location using lsp
                          -- none:      this will make this option ignored
    target = vim.loop.cwd() -- path to directory, this is used only if action == "soft_link" or action == "copy"
  },
  cmake_kits_path = nil, -- this is used to specify global cmake kits path, see CMakeKits for detailed usage
  cmake_variants_message = {
    short = { show = true }, -- whether to show short message
    long = { show = true, max_length = 40 }, -- whether to show long message
  },
  cmake_dap_configuration = { -- debug settings for cmake
    name = "cpp",
    type = "codelldb",
    request = "launch",
    stopOnEntry = false,
    runInTerminal = true,
    console = "integratedTerminal",
  },
  cmake_executor = { -- executor to use
    name = "quickfix", -- name of the executor
    opts = {}, -- the options the executor will get, possible values depend on the executor type. See `default_opts` for possible values.
    default_opts = { -- a list of default and possible values for executors
      quickfix = {
        show = "always", -- "always", "only_on_error"
        position = "belowright", -- "vertical", "horizontal", "leftabove", "aboveleft", "rightbelow", "belowright", "topleft", "botright", use `:h vertical` for example to see help on them
        size = 10,
        encoding = "utf-8", -- if encoding is not "utf-8", it will be converted to "utf-8" using `vim.fn.iconv`
        auto_close_when_success = true, -- typically, you can use it with the "always" option; it will auto-close the quickfix buffer if the execution is successful.
      },
      toggleterm = {
        direction = "float", -- 'vertical' | 'horizontal' | 'tab' | 'float'
        close_on_exit = false, -- whether close the terminal when exit
        auto_scroll = true, -- whether auto scroll to the bottom
        singleton = true, -- single instance, autocloses the opened one, if present
      },
      overseer = {
        new_task_opts = {
            strategy = {
                "toggleterm",
                direction = "horizontal",
                auto_scroll = true,
                quit_on_exit = "success"
            }
        }, -- options to pass into the `overseer.new_task` command
        on_new_task = function(task)
            require("overseer").open(
                { enter = false, direction = "right" }
            )
        end,   -- a function that gets overseer.Task when it is created, before calling `task:start`
      },
      terminal = {
        name = "Main Terminal",
        prefix_name = "[CMakeTools]: ", -- This must be included and must be unique, otherwise the terminals will not work. Do not use a simple spacebar " ", or any generic name
        split_direction = "horizontal", -- "horizontal", "vertical"
        split_size = 11,

        -- Window handling
        single_terminal_per_instance = true, -- Single viewport, multiple windows
        single_terminal_per_tab = true, -- Single viewport per tab
        keep_terminal_static_location = true, -- Static location of the viewport if avialable
        auto_resize = true, -- Resize the terminal if it already exists

        -- Running Tasks
        start_insert = false, -- If you want to enter terminal with :startinsert upon using :CMakeRun
        focus = false, -- Focus on terminal when cmake task is launched.
        do_not_add_newline = false, -- Do not hit enter on the command inserted when using :CMakeRun, allowing a chance to review or modify the command before hitting enter.
      }, -- terminal executor uses the values in cmake_terminal
    },
  },
  cmake_runner = { -- runner to use
    name = "terminal", -- name of the runner
    opts = {}, -- the options the runner will get, possible values depend on the runner type. See `default_opts` for possible values.
    default_opts = { -- a list of default and possible values for runners
      quickfix = {
        show = "always", -- "always", "only_on_error"
        position = "belowright", -- "bottom", "top"
        size = 10,
        encoding = "utf-8",
        auto_close_when_success = true, -- typically, you can use it with the "always" option; it will auto-close the quickfix buffer if the execution is successful.
      },
      toggleterm = {
        direction = "float", -- 'vertical' | 'horizontal' | 'tab' | 'float'
        close_on_exit = false, -- whether close the terminal when exit
        auto_scroll = true, -- whether auto scroll to the bottom
        singleton = true, -- single instance, autocloses the opened one, if present
      },
      overseer = {
        new_task_opts = {
            strategy = {
                "toggleterm",
                direction = "horizontal",
                autos_croll = true,
                quit_on_exit = "success"
            }
        }, -- options to pass into the `overseer.new_task` command
        on_new_task = function(task)
        end,   -- a function that gets overseer.Task when it is created, before calling `task:start`
      },
      terminal = {
        name = "Main Terminal",
        prefix_name = "[CMakeTools]: ", -- This must be included and must be unique, otherwise the terminals will not work. Do not use a simple spacebar " ", or any generic name
        split_direction = "horizontal", -- "horizontal", "vertical"
        split_size = 11,

        -- Window handling
        single_terminal_per_instance = true, -- Single viewport, multiple windows
        single_terminal_per_tab = true, -- Single viewport per tab
        keep_terminal_static_location = true, -- Static location of the viewport if avialable
        auto_resize = true, -- Resize the terminal if it already exists

        -- Running Tasks
        start_insert = false, -- If you want to enter terminal with :startinsert upon using :CMakeRun
        focus = false, -- Focus on terminal when cmake task is launched.
        do_not_add_newline = false, -- Do not hit enter on the command inserted when using :CMakeRun, allowing a chance to review or modify the command before hitting enter.
      },
    },
  },
  cmake_notifications = {
    runner = { enabled = true },
    executor = { enabled = true },
    spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }, -- icons used for progress display
    refresh_rate_ms = 100, -- how often to iterate icons
  },
  cmake_virtual_text_support = true, -- Show the target related to current file using virtual text (at right corner)
  cmake_use_scratch_buffer = false, -- A buffer that shows what cmake-tools has done
}

-- local auto_dark_mode = require("auto-dark-mode")
--
-- auto_dark_mode.setup({
--   update_interval = 1000,
--
--   set_dark_mode = function()
--     -- ✅ 新 API，无警告
--     vim.opt.background = "dark"
--     vim.cmd("colorscheme tokyonight-storm")
--   end,
--
--   set_light_mode = function()
--     -- ✅ 新 API，无警告
--     vim.opt.background = "light"
--     vim.cmd("colorscheme tokyonight-day")
--   end,
-- })
--
-- auto_dark_mode.init()
