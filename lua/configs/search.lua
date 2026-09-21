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

function M.live_grep(opts)
  opts = opts or {}
  local conf = require("telescope.config").values
  local finders = require "telescope.finders"
  local make_entry = require "telescope.make_entry"
  local pickers = require "telescope.pickers"
  local sorters = require "telescope.sorters"

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
      end, make_entry.gen_from_vimgrep(opts), opts.max_results, opts.cwd),
      previewer = conf.grep_previewer(opts),
      sorter = (function()
        local sorter = sorters.highlighter_only(opts)
        local orig = sorter.highlighter
        sorter.highlighter = function(self, prompt, display)
          local search = split_query(prompt)
          return orig(self, search, display)
        end
        return sorter
      end)(),
      attach_mappings = attach_ignore_toggle("grep", opts),
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
      sorter = conf.file_sorter(opts),
      attach_mappings = attach_ignore_toggle("files", opts),
      on_input_filter_cb = function(prompt)
        local name = split_query(prompt)
        return { prompt = name }
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
