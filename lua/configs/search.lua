local M = {}

local function split_query(prompt)
  prompt = prompt or ""
  local sep = prompt:find(";", 1, true)
  if not sep then
    return vim.trim(prompt), ""
  end
  return vim.trim(prompt:sub(1, sep - 1)), vim.trim(prompt:sub(sep + 1))
end

local function append_globs(args, scope)
  if scope == "" then
    return
  end
  if scope:find "[*?]" then
    table.insert(args, "--glob")
    table.insert(args, scope)
    return
  end
  if scope:sub(1, 1) == "." then
    table.insert(args, "--glob")
    table.insert(args, "*" .. scope)
    return
  end
  table.insert(args, "--glob")
  table.insert(args, "**/*" .. scope .. "*/**")
  table.insert(args, "--glob")
  table.insert(args, "**/*" .. scope .. "*")
end

local function history_path()
  local conf = require("telescope.config").values
  if type(conf.history) == "table" and conf.history.path then
    return conf.history.path
  end
  return vim.fn.stdpath "data" .. "/telescope_history"
end

local function history_entries()
  local path = history_path()
  if not vim.uv.fs_stat(path) then
    return {}
  end
  local seen = {}
  local entries = {}
  local lines = vim.fn.readfile(path)
  for i = #lines, 1, -1 do
    local line = vim.trim(lines[i])
    if line ~= "" and not seen[line] then
      seen[line] = true
      table.insert(entries, line)
    end
  end
  return entries
end

local function apply_ignore(args, no_ignore)
  if no_ignore then
    table.insert(args, "--no-ignore-vcs")
    table.insert(args, "--hidden")
    table.insert(args, "--glob")
    table.insert(args, "!.git/**")
  end
end

local function prompt_title(base, no_ignore)
  if no_ignore then
    return base .. "  |  C-a ignore ON"
  end
  return base .. "  |  C-a ignore"
end

local function filename_sorter(opts)
  local sorters = require "telescope.sorters"
  local fzy = require "telescope.algos.fzy"
  local OFFSET = -fzy.get_score_floor()

  local function basename(path)
    return (path:match "[^/]+$" or path)
  end

  -- filename_first：图标 文件名 目录
  local function display_parts(display)
    local start = display:find "%S"
    if not start then
      return 1, display, nil, ""
    end
    local tok_s, tok_e = display:find("%S+", start)
    if not tok_s then
      return 1, display, nil, ""
    end
    local tok = display:sub(tok_s, tok_e)
    -- 跳过 nerd icon；无扩展名的文件名（Makefile）仍要留下
    if not tok:match "^[%w._%-]+$" then
      local next_s, next_e = display:find("%S+", tok_e + 1)
      if next_s then
        tok_s, tok_e = next_s, next_e
      end
    end
    local file = display:sub(tok_s, tok_e)
    local path_s = display:find("%S", tok_e + 1)
    local path = path_s and display:sub(path_s) or ""
    return tok_s, file, path_s, path
  end

  local function shift_positions(positions, offset)
    for i, pos in ipairs(positions) do
      positions[i] = pos + offset
    end
    return positions
  end

  return sorters.Sorter:new {
    discard = true,
    scoring_function = function(_, prompt, line)
      -- on_input_filter_cb 已把 prompt 收成文件名；空表示只按路径 glob 筛
      if prompt == "" then
        return 1
      end
      local file = basename(line)
      if not fzy.has_match(prompt, file) then
        return -1
      end
      local score = fzy.score(prompt, file)
      if score == fzy.get_score_min() then
        return 1
      end
      return 1 / (score + OFFSET)
    end,
    highlighter = function(_, prompt, display)
      local name, scope = split_query(prompt)
      local file_s, file, path_s, path = display_parts(display)
      local marks = {}
      if name ~= "" then
        vim.list_extend(marks, shift_positions(fzy.positions(name, file) or {}, file_s - 1))
      end
      if scope ~= "" and path_s then
        vim.list_extend(marks, shift_positions(fzy.positions(scope, path) or {}, path_s - 1))
      end
      return marks
    end,
  }
end

local function attach_ignore_toggle(kind, opts)
  return function(_, map)
    local actions = require "telescope.actions"
    local action_state = require "telescope.actions.state"
    local function toggle(prompt_bufnr)
      local text = action_state.get_current_line()
      actions.close(prompt_bufnr)
      local next_opts = vim.tbl_extend("force", opts, {
        default_text = text,
        no_ignore = not opts.no_ignore,
      })
      if kind == "files" then
        M.find_files(next_opts)
      else
        M.live_grep(next_opts)
      end
    end
    map("i", "<C-a>", toggle, { desc = "toggle gitignore" })
    map("n", "<C-a>", toggle, { desc = "toggle gitignore" })
    return true
  end
end

-- 结果区一行折成两行：文件名+路径 / 代码片段。highlighter 用这份偏移打匹配。
local grep_display_meta = {}

local function results_inner_width()
  local ok, state = pcall(require, "telescope.state")
  if not ok then
    return 80
  end
  local status = state.get_status(vim.api.nvim_get_current_buf())
  local win = status and status.layout and status.layout.results and status.layout.results.winid
  if not win or not vim.api.nvim_win_is_valid(win) then
    return 80
  end
  local caret = 2
  local picker = status.picker
  if picker and picker.selection_caret then
    caret = vim.fn.strdisplaywidth(picker.selection_caret)
  end
  return math.max(24, vim.api.nvim_win_get_width(win) - caret)
end

local function grep_entry_maker(opts)
  local make_entry = require "telescope.make_entry"
  local inner = make_entry.gen_from_vimgrep(opts)
  local disable_devicons = opts.disable_devicons
  local has_devicons, devicons = pcall(require, "nvim-web-devicons")

  local function grep_display(entry)
    local filename = entry.filename or ""
    local fname = vim.fn.fnamemodify(filename, ":t")
    local dir = vim.fn.fnamemodify(filename, ":h")
    if dir == "." then
      dir = ""
    end
    local snippet = vim.trim(entry.text or ""):gsub("%s+", " ")
    local lnum = entry.lnum and tostring(entry.lnum) or ""

    local icon, icon_hl = " ", nil
    if has_devicons and not disable_devicons then
      local i, hl = devicons.get_icon(fname, vim.fn.fnamemodify(fname, ":e"), { default = true })
      icon, icon_hl = i or " ", hl
    end

    local path_bit = dir
    if lnum ~= "" then
      path_bit = dir == "" and (":" .. lnum) or (dir .. ":" .. lnum)
    end
    local header = icon .. " " .. fname
    if path_bit ~= "" then
      header = header .. "  " .. path_bit
    end

    local dw = vim.fn.strdisplaywidth(header)
    local width = results_inner_width()
    local pad = math.max(1, width - dw)
    local snippet_prefix = "│ "
    local display = header .. string.rep(" ", pad) .. snippet_prefix .. snippet

    local fname_col = #icon + 2
    local snippet_col = #header + pad + #snippet_prefix + 1
    grep_display_meta[display] = {
      fname = fname,
      fname_col = fname_col,
      snippet = snippet,
      snippet_col = snippet_col,
    }

    local hl = {}
    if icon_hl then
      table.insert(hl, { { 0, #icon }, icon_hl })
    end
    table.insert(hl, { { #icon + 1, #icon + 1 + #fname }, "TelescopeResultsFilename" })
    if path_bit ~= "" then
      local path_start = #(icon .. " " .. fname .. "  ")
      table.insert(hl, { { path_start, #header }, "TelescopeResultsComment" })
    end
    table.insert(hl, { { #header + pad, #header + pad + #snippet_prefix }, "TelescopeResultsComment" })
    return display, hl
  end

  return function(line)
    local entry = inner(line)
    if not entry then
      return nil
    end
    return setmetatable({}, {
      __index = function(_, k)
        if k == "display" then
          return grep_display
        end
        return entry[k]
      end,
    })
  end
end

local function enable_results_wrap(prompt_bufnr)
  local picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
  local win = picker and picker.results_win
  if win and vim.api.nvim_win_is_valid(win) then
    vim.wo[win].wrap = true
    vim.wo[win].linebreak = false
    vim.wo[win].breakindent = true
  end
end

function M.live_grep(opts)
  opts = opts or {}
  local conf = require("telescope.config").values
  local finders = require "telescope.finders"
  local pickers = require "telescope.pickers"
  local sorters = require "telescope.sorters"
  local fzy = require "telescope.algos.fzy"

  pickers
    .new(opts, {
      prompt_title = prompt_title("Live Grep  (text;path)", opts.no_ignore),
      finder = finders.new_job(function(prompt)
        local search, scope = split_query(prompt)
        if search == "" then
          return nil
        end

        local args = vim.deepcopy(conf.vimgrep_arguments)
        if opts.literal then
          table.insert(args, "--fixed-strings")
        end
        table.insert(args, "--glob-case-insensitive")
        apply_ignore(args, opts.no_ignore)
        append_globs(args, scope)
        table.insert(args, "--")
        table.insert(args, search)
        return args
      end, grep_entry_maker(opts), opts.max_results, opts.cwd),
      previewer = conf.grep_previewer(opts),
      sorter = (function()
        local sorter = sorters.highlighter_only(opts)
        sorter.highlighter = function(_, prompt, display)
          local search = split_query(prompt)
          if search == "" then
            return {}
          end
          local meta = grep_display_meta[display]
          if not meta then
            return fzy.positions(search, display)
          end
          local marks = {}
          local function add(str, col)
            for _, pos in ipairs(fzy.positions(search, str) or {}) do
              table.insert(marks, pos + col - 1)
            end
          end
          add(meta.fname, meta.fname_col)
          add(meta.snippet, meta.snippet_col)
          return marks
        end
        return sorter
      end)(),
      attach_mappings = function(prompt_bufnr, map)
        vim.schedule(function()
          enable_results_wrap(prompt_bufnr)
        end)
        return attach_ignore_toggle("grep", opts)(prompt_bufnr, map)
      end,
      push_cursor_on_edit = true,
    })
    :find()
end

function M.find_files(opts)
  opts = opts or {}
  local conf = require("telescope.config").values
  local finders = require "telescope.finders"
  local make_entry = require "telescope.make_entry"
  local pickers = require "telescope.pickers"

  pickers
    .new(opts, {
      prompt_title = prompt_title("Find Files  (name;path)", opts.no_ignore),
      finder = finders.new_job(function(prompt)
        local _, scope = split_query(prompt)
        local args = {
          "rg",
          "--files",
          "--color",
          "never",
          "--glob-case-insensitive",
        }
        apply_ignore(args, opts.no_ignore)
        append_globs(args, scope)
        return args
      end, make_entry.gen_from_file(opts), opts.max_results, opts.cwd),
      previewer = conf.file_previewer(opts),
      sorter = filename_sorter(opts),
      attach_mappings = attach_ignore_toggle("files", opts),
      on_input_filter_cb = function(prompt)
        local name = split_query(prompt)
        return { prompt = name }
      end,
    })
    :find()
end

function M.projects()
  require("telescope").extensions.project.project {
    display_type = "full",
    prompt_title = "Projects  |  CR打开  C-y加cwd  C-a加git根  C-d删除  C-l只切目录",
    results_title = "n: C加cwd  d删除  w只切目录",
  }
end

local GIT_WALK_SKIP = {
  [".git"] = true,
  node_modules = true,
  vendor = true,
  dist = true,
  build = true,
  target = true,
  [".cache"] = true,
  [".direnv"] = true,
}

local function is_git_root(path)
  return vim.uv.fs_stat(path .. "/.git") ~= nil
end

local function git_branch(path)
  local out = vim.system({ "git", "-C", path, "rev-parse", "--abbrev-ref", "HEAD" }, { text = true }):wait()
  if out.code ~= 0 then
    return "?"
  end
  return vim.trim(out.stdout)
end

local function collect_git_repos(root, max_depth)
  local found = {}
  local function walk(dir, depth)
    if is_git_root(dir) then
      table.insert(found, dir)
    end
    if depth >= max_depth then
      return
    end
    local fs = vim.uv.fs_scandir(dir)
    if not fs then
      return
    end
    while true do
      local name, typ = vim.uv.fs_scandir_next(fs)
      if not name then
        break
      end
      if not GIT_WALK_SKIP[name] and (typ == "directory" or typ == "link") then
        walk(dir .. "/" .. name, depth + 1)
      end
    end
  end
  walk(root, 0)
  table.sort(found)
  return found
end

function M.git_repos()
  local root = vim.uv.cwd()
  local repos = collect_git_repos(root, 5)
  if #repos == 0 then
    vim.notify("当前目录下没有 git 仓库", vim.log.levels.WARN)
    return
  end

  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local builtin = require "telescope.builtin"
  local conf = require("telescope.config").values
  local finders = require "telescope.finders"
  local pickers = require "telescope.pickers"

  pickers
    .new({}, {
      prompt_title = "Git repos  |  CR status",
      finder = finders.new_table {
        results = repos,
        entry_maker = function(path)
          local rel = vim.fn.fnamemodify(path, ":.")
          if rel == "." then
            rel = vim.fn.fnamemodify(path, ":t") .. "  (cwd)"
          end
          local display = string.format("%-24s  %s", git_branch(path), rel)
          return {
            value = path,
            display = display,
            ordinal = rel .. " " .. display,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(_, map)
        actions.select_default:replace(function(prompt_bufnr)
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not entry or not entry.value then
            return
          end
          builtin.git_status {
            cwd = entry.value,
            prompt_title = "Git status  " .. vim.fn.fnamemodify(entry.value, ":t"),
          }
        end)
        return true
      end,
    })
    :find()
end

function M.prompt_history()
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local conf = require("telescope.config").values
  local finders = require "telescope.finders"
  local pickers = require "telescope.pickers"

  pickers
    .new({}, {
      prompt_title = "Telescope History",
      finder = finders.new_table { results = history_entries() },
      sorter = conf.generic_sorter {},
      attach_mappings = function(_, map)
        local function reopen(kind)
          return function(prompt_bufnr)
            local entry = action_state.get_selected_entry()
            local text = entry and (entry.value or entry[1]) or ""
            actions.close(prompt_bufnr)
            if text == "" then
              return
            end
            if kind == "files" then
              M.find_files { default_text = text }
            else
              M.live_grep { default_text = text }
            end
          end
        end
        actions.select_default:replace(reopen "grep")
        map("i", "<C-f>", reopen "files")
        map("n", "<C-f>", reopen "files")
        return true
      end,
    })
    :find()
end

return M
