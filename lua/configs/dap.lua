-- nvim-dap + cmake-tools(codelldb) / Python / Go。
-- F5 仍是 CMakeRun，调试用 Shift-F5 和 ,d* 。

local M = {}

function M.setup()
  local dap = require "dap"

  require("mason-nvim-dap").setup {
    ensure_installed = { "codelldb", "python", "delve" },
    automatic_installation = true,
    handlers = {},
  }

  require("nvim-dap-virtual-text").setup {
    commented = true,
  }

  vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
  vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "CursorLine" })

  local ok, view = pcall(require, "dap-view")
  if ok then
    dap.listeners.after.event_initialized["dap-view"] = function()
      view.open()
    end
    dap.listeners.before.event_terminated["dap-view"] = function()
      view.close()
    end
    dap.listeners.before.event_exited["dap-view"] = function()
      view.close()
    end
  end
end

function M.keys()
  local dap = function()
    return require "dap"
  end
  return {
    { "<F9>", function() dap().toggle_breakpoint() end, desc = "DAP 断点" },
    { "<F10>", function() dap().step_over() end, desc = "DAP 步过" },
    { "<F11>", function() dap().step_into() end, desc = "DAP 步入" },
    { "<F8>", function() dap().step_out() end, desc = "DAP 步出" },
    { "<S-F5>", "<cmd>CMakeDebug<cr>", desc = "CMake 调试" },
    { "<leader>db", function() dap().toggle_breakpoint() end, desc = "DAP 断点" },
    { "<leader>dc", function() dap().continue() end, desc = "DAP 继续/启动" },
    { "<leader>dC", "<cmd>CMakeDebug<cr>", desc = "CMake 调试" },
    { "<leader>do", function() dap().step_over() end, desc = "DAP 步过" },
    { "<leader>di", function() dap().step_into() end, desc = "DAP 步入" },
    { "<leader>du", function() dap().step_out() end, desc = "DAP 步出" },
    { "<leader>dx", function() dap().terminate() end, desc = "DAP 结束" },
    {
      "<leader>dv",
      function()
        require("dap-view").toggle()
      end,
      desc = "DAP 面板",
    },
  }
end

return M
