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

function M.after_setup()
  local render = require "avante.history.render"
  local orig = render.message_to_lines
  function render.message_to_lines(message, messages, expanded)
    local ok, helpers = pcall(require, "avante.history.helpers")
    if ok and helpers.is_thinking_message(message) then
      return {}
    end
    return orig(message, messages, expanded)
  end

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "AvanteInput",
    callback = function(ev)
      local buf = ev.buf
      vim.keymap.set("n", "<leader>cM", M.select_model, { buffer = buf, desc = "CodeBuddy 切换模型" })
      vim.keymap.set("n", "<leader>cP", M.select_mode, { buffer = buf, desc = "CodeBuddy 切换模式" })
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
        height = 4,
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

function M.toggle()
  require("avante").toggle()
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
