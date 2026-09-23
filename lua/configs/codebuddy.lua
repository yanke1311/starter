-- CodeBuddy（国内 WorkBuddy）走 ACP，界面用 avante 侧边栏。
-- VS Code 插件快捷键：https://www.codebuddy.cn/docs/plugin/

local M = {}

local function ask(opts)
  require("avante.api").ask(opts)
end

-- CodeBuddy 会推 _codebuddy.ai/* 私有 ACP 通知；Avante 只认标准方法，忽略即可。
local function ignore_vendor_acp_noise()
  if vim.g._codebuddy_acp_notify_patched then
    return
  end
  vim.g._codebuddy_acp_notify_patched = true
  local orig = vim.notify
  vim.notify = function(msg, level, opts)
    if type(msg) == "string" and msg:find("Unknown notification method: _codebuddy.ai/", 1, true) then
      return
    end
    return orig(msg, level, opts)
  end
end

local function ensure_sidebar(then_fn)
  local avante = require "avante"
  if not avante.is_sidebar_open() then
    avante.open_sidebar {}
  end
  vim.schedule(then_fn)
end

function M.select_model()
  ensure_sidebar(function()
    require("avante.api").select_acp_model()
  end)
end

function M.select_mode()
  ensure_sidebar(function()
    require("avante.api").select_acp_mode()
  end)
end

local INPUT_HINT = "%#Comment# <CR>提交  <S-CR>换行"

local function apply_input_win_opts(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win].wrap = true
      vim.wo[win].linebreak = true
      vim.wo[win].breakindent = true
      vim.wo[win].scrolloff = 1
    end
  end
end

local function append_submit_hint(win)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local cur = vim.wo[win].winbar or ""
  if cur:find("提交", 1, true) then
    return
  end
  vim.wo[win].winbar = cur .. "%=" .. INPUT_HINT
end

function M.after_setup()
  -- 隐藏 thinking 气泡；找不到接口就跳过，避免 Avante 升级直接报错。
  pcall(function()
    local render = require "avante.history.render"
    local orig = render.message_to_lines
    if type(orig) ~= "function" then
      return
    end
    function render.message_to_lines(message, messages, expanded)
      local ok, helpers = pcall(require, "avante.history.helpers")
      if ok and helpers.is_thinking_message and helpers.is_thinking_message(message) then
        return {}
      end
      local ran, result = pcall(orig, message, messages, expanded)
      if ran then
        return result
      end
      return {}
    end
  end)

  -- 关掉默认浮层 hint（会盖住输入）。提交说明接到 Avante 自己的 winbar 右侧，不覆盖标题。
  pcall(function()
    local Sidebar = require "avante.sidebar"
    function Sidebar:show_input_hint() end
    local orig_header = Sidebar.render_header
    if type(orig_header) ~= "function" then
      return
    end
    function Sidebar:render_header(winid, bufnr, header_text, hl, reverse_hl, opts)
      orig_header(self, winid, bufnr, header_text, hl, reverse_hl, opts)
      local input = self.containers and self.containers.input
      if input and winid == input.winid then
        append_submit_hint(winid)
      end
    end
  end)

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "AvanteInput",
    callback = function(ev)
      local buf = ev.buf
      vim.keymap.set("n", "<leader>cM", M.select_model, { buffer = buf, desc = "CodeBuddy 切换模型" })
      vim.keymap.set("n", "<leader>cP", M.select_mode, { buffer = buf, desc = "CodeBuddy 切换模式" })
      -- Enter 提交后，Shift-Enter 换行（Kitty 键盘协议下 <S-CR> 能和 Enter 区分）
      vim.keymap.set("i", "<S-CR>", "<C-j>", { buffer = buf, desc = "Avante 换行" })
      apply_input_win_opts(buf)
      vim.api.nvim_create_autocmd("BufWinEnter", {
        buffer = buf,
        callback = function()
          apply_input_win_opts(buf)
        end,
      })
    end,
  })
end

function M.opts()
  -- 国内账号；CLI 已 login 时不必再塞 API Key
  vim.env.CODEBUDDY_INTERNET_ENVIRONMENT = "internal"
  ignore_vendor_acp_noise()

  local cli = require "configs.cli_path"
  local acp = cli.codebuddy_acp()

  return {
    provider = "codebuddy",
    mode = "agentic",
    auto_suggestions_provider = nil,
    selector = { provider = "telescope" },
    input = { provider = "native" },
    mappings = {
      submit = {
        normal = "<CR>",
        insert = "<CR>",
      },
    },
    behaviour = {
      auto_suggestions = false,
      auto_set_keymaps = false,
      auto_apply_diff_after_generation = false,
      auto_approve_tool_permissions = false,
      auto_add_current_file = false,
      acp_follow_agent_locations = false,
      confirmation_ui_style = "popup",
      enable_token_counting = false,
    },
    selection = {
      enabled = true,
      hint_display = "none",
    },
    windows = {
      position = "right",
      wrap = true,
      width = 30,
      sidebar_header = {
        enabled = true,
        align = "left",
        rounded = false,
        include_model = true,
      },
      input = {
        prefix = "> ",
        height = 8,
      },
      selected_files = {
        height = 3,
      },
    },
    slash_commands = {
      {
        name = "mode",
        description = "切换 CodeBuddy 权限模式",
        details = "打开 default / plan / acceptEdits 等模式选择器",
        callback = function(_, _, cb)
          require("avante.api").select_acp_mode()
          if cb then
            cb ""
          end
        end,
      },
    },
    acp_providers = {
      codebuddy = {
        command = acp.command,
        args = acp.args,
        env = cli.child_env {
          CODEBUDDY_INTERNET_ENVIRONMENT = "internal",
        },
      },
    },
  }
end

local function sidebar_has_win(sidebar, win)
  if not sidebar or not sidebar.containers then
    return false
  end
  for _, container in pairs(sidebar.containers) do
    if container and container.winid == win then
      return true
    end
  end
  return false
end

local function focus_input()
  vim.cmd "stopinsert"
  -- Avante 打开 ACP 侧栏时会先 focus 结果窗、再空 submit；稍后再抢输入栏。
  vim.defer_fn(function()
    local sidebar = require("avante").get()
    if not sidebar or not sidebar.is_open or not sidebar:is_open() then
      return
    end
    if sidebar.focus_input then
      sidebar:focus_input()
    end
    local input = sidebar.containers and sidebar.containers.input
    if not input or not input.winid or not vim.api.nvim_win_is_valid(input.winid) then
      return
    end
    vim.api.nvim_set_current_win(input.winid)
    vim.cmd "startinsert!"
  end, 80)
end

function M.toggle()
  local avante = require "avante"
  local sidebar = avante.get()
  if sidebar and sidebar:is_open() then
    if sidebar_has_win(sidebar, vim.api.nvim_get_current_win()) then
      -- 输入栏里是插入模式；关掉后焦点回到代码窗，不能把 insert 带回去。
      vim.cmd "stopinsert"
      avante.toggle()
      vim.schedule(function()
        vim.cmd "stopinsert"
      end)
      return
    end
    focus_input()
    return
  end
  avante.open_sidebar {}
  focus_input()
end

function M.inline()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    require("avante.api").edit()
    return
  end
  ask { floating = true }
end

function M.new_chat()
  ask { new_chat = true }
end

function M.explain()
  ask { question = "解释这段代码的作用、关键逻辑和潜在问题。" }
end

function M.fix()
  ask { question = "修复这段代码的问题，只做最小改动，并说明原因。" }
end

function M.comment()
  ask { question = "为这段代码添加清晰的中文注释，不要改逻辑。" }
end

function M.tests()
  ask { question = "为这段代码生成单元测试，覆盖主要分支和边界情况。" }
end

return M
