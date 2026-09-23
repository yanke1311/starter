return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    dependencies = { "saghen/blink.cmp" },
    config = function()
      require "configs.lspconfig"
    end,
  },
  {
    "folke/flash.nvim",
    event = { "VeryLazy", "CmdlineEnter" },
    opts = {
      -- leader 是 `,`，关掉 char 模式避免和 f/t 的重复查找抢键
      -- / 搜索不要默认出标签：输入 pn 时 n 会被当成跳转键，直接退出 cmdline
      modes = {
        char = { enabled = false },
        search = { enabled = false },
      },
    },
    keys = require("configs.flash").keys(),
  },

  {
    "Civitasv/cmake-tools.nvim",
    opts = {},
    dependencies = { "mfussenegger/nvim-dap" },
  },
  {
    "stevearc/oil.nvim",
    cmd = "Oil",
    opts = function()
      return require("configs.oil").opts()
    end,
    keys = function()
      return require("configs.oil").keys()
    end,
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "mason-org/mason.nvim",
      "jay-babu/mason-nvim-dap.nvim",
      "theHamsta/nvim-dap-virtual-text",
      {
        "igorlfs/nvim-dap-view",
        opts = {
          winbar = { show = true },
          windows = { size = 10 },
        },
      },
    },
    config = function()
      require("configs.dap").setup()
    end,
    keys = function()
      return require("configs.dap").keys()
    end,
  },
  {
    "lewis6991/satellite.nvim",
    event = "VeryLazy",
    opts = require "configs.satellite",
  },
  {
    "HiPhish/rainbow-delimiters.nvim",
    submodules = false,
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("configs.rainbow_delimiters").setup()
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = { "BufReadPost", "BufNewFile" },
    opts = require "configs.treesitter_context",
  },
  {
    "kylechui/nvim-surround",
    version = "^3.0.0", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    config = function()
        require("nvim-surround").setup({
            -- Configuration here, or leave empty to use defaults
        })
    end
  },
  {
    "nvim-tree/nvim-tree.lua",
    opts = {
      filters = {
        git_ignored = false,
      },
    },
  },
  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, opts)
      local actions = require "telescope.actions"
      local action_state = require "telescope.actions.state"
      local sorters = require "telescope.sorters"

      local function strip_scope(prompt)
        local cut = prompt:find(";", 1, true)
        return cut and vim.trim(prompt:sub(1, cut - 1)) or prompt
      end

      local function wrap_highlighter(sorter)
        local orig = sorter.highlighter
        if orig then
          sorter.highlighter = function(self, prompt, display)
            return orig(self, strip_scope(prompt), display)
          end
        end
        return sorter
      end

      local function apply_telescope_hl()
        local colors = require("base46").get_theme_tb "base_30"
        -- 不设 selection 的 fg，避免盖住匹配高亮
        vim.api.nvim_set_hl(0, "TelescopeMatching", { fg = colors.orange, bold = true, bg = "NONE" })
        vim.api.nvim_set_hl(0, "TelescopeSelection", { bg = colors.one_bg3, bold = true })
        vim.api.nvim_set_hl(0, "TelescopeResultsComment", { fg = colors.light_grey })
      end

      apply_telescope_hl()
      vim.api.nvim_create_autocmd("User", {
        pattern = { "TelescopeFindPre", "NvThemeReload" },
        callback = apply_telescope_hl,
      })

      local function close_saving(prompt_bufnr)
        local picker = action_state.get_current_picker(prompt_bufnr)
        action_state.get_current_history():append(action_state.get_current_line(), picker)
        actions.close(prompt_bufnr)
      end

      opts.defaults = opts.defaults or {}
      opts.defaults.path_display = { "filename_first" }
      opts.defaults.selection_caret = "▎ "
      opts.defaults.entry_prefix = "  "
      opts.defaults.file_sorter = function(sopts)
        return wrap_highlighter(sorters.get_fzy_sorter(sopts))
      end
      opts.defaults.layout_config = vim.tbl_deep_extend("force", opts.defaults.layout_config or {}, {
        width = 0.92,
        height = 0.85,
        horizontal = {
          prompt_position = "top",
          preview_width = 0.5,
        },
      })
      opts.defaults.history = vim.tbl_extend("force", opts.defaults.history or {}, {
        cycle_wrap = true,
        limit = 200,
      })
      opts.defaults.mappings = vim.tbl_deep_extend("force", opts.defaults.mappings or {}, {
        i = {
          ["<C-j>"] = actions.move_selection_next,
          ["<C-k>"] = actions.move_selection_previous,
          ["<C-n>"] = actions.cycle_history_next,
          ["<C-p>"] = actions.cycle_history_prev,
          ["<C-c>"] = close_saving,
        },
        n = {
          ["q"] = close_saving,
          ["<Esc>"] = close_saving,
        },
      })
      return opts
    end,
  },

  { import = "nvchad.blink.lazyspec" },
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.completion = opts.completion or {}
      opts.completion.list = vim.tbl_deep_extend("force", opts.completion.list or {}, {
        -- 菜单弹出时不预选第一项，没动手选时回车只换行
        selection = { preselect = false, auto_insert = false },
      })
      opts.sources = opts.sources or {}
      opts.sources.providers = vim.tbl_deep_extend("force", opts.sources.providers or {}, {
        avante_commands = {
          name = "Avante",
          module = "configs.blink_avante_commands",
        },
      })
      opts.sources.per_filetype = vim.tbl_deep_extend("force", opts.sources.per_filetype or {}, {
        AvanteInput = { "avante_commands" },
      })
      return opts
    end,
  },

  -- NvChad 仍 lazy-load treesitter，0.12 的 main 分支不允许。覆盖为立即加载。
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    branch = "main",
    event = false,
    cmd = { "TSUpdate", "TSInstall", "TSUninstall", "TSLog", "TSInstallAll" },
    build = ":TSUpdate",
    opts = function()
      local opts = require "nvchad.configs.treesitter"
      opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, {
        "c",
        "cpp",
        "cmake",
        "python",
        "go",
        "rust",
        "markdown",
        "markdown_inline",
        "json",
      })
      return opts
    end,
    config = function(_, opts)
      require("nvim-treesitter").setup {}
      if opts and opts.ensure_installed then
        require("nvim-treesitter").install(opts.ensure_installed)
      end
    end,
  },

  {
    "yetone/avante.nvim",
    version = false,
    build = "make",
    cmd = {
      "AvanteAsk",
      "AvanteToggle",
      "AvanteEdit",
      "AvanteChat",
      "AvanteChatNew",
      "AvanteStop",
      "AvanteACPModels",
      "AvanteACPModes",
    },
    opts = function()
      return require("configs.codebuddy").opts()
    end,
    config = function(_, opts)
      require("avante").setup(opts)
      require("configs.codebuddy").after_setup()
    end,
    keys = function()
      local cb = require "configs.codebuddy"
      local nvi = { "n", "v", "i" }
      local nv = { "n", "v" }
      return {
        -- VS Code CodeBuddy 插件 / IDE（Mac）
        { "<D-C-i>", cb.toggle, mode = nvi, desc = "CodeBuddy 侧边栏对话" },
        { "<C-D-i>", cb.toggle, mode = nvi, desc = "CodeBuddy 侧边栏对话" },
        { "<D-i>", cb.inline, mode = nvi, desc = "CodeBuddy 内联对话" },
        { "<D-C-n>", cb.new_chat, mode = nvi, desc = "CodeBuddy 新对话" },
        { "<C-D-n>", cb.new_chat, mode = nvi, desc = "CodeBuddy 新对话" },
        { "<M-S-x>", cb.explain, mode = nv, desc = "CodeBuddy 解释代码" },
        { "<M-S-y>", cb.fix, mode = nv, desc = "CodeBuddy 修复代码" },
        { "<M-S-m>", cb.comment, mode = nv, desc = "CodeBuddy 添加注释" },
        { "<M-S-t>", cb.tests, mode = nv, desc = "CodeBuddy 生成测试" },
        -- 终端里 Cmd 经常到不了 nvim
        { "<leader>cc", cb.toggle, desc = "CodeBuddy 侧边栏对话" },
        { "<leader>cM", cb.select_model, mode = { "n", "v" }, desc = "CodeBuddy 切换模型" },
        { "<leader>cP", cb.select_mode, mode = { "n", "v" }, desc = "CodeBuddy 切换模式" },
      }
    end,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
      {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown", "Avante" },
        opts = function()
          return require("configs.render_markdown").opts
        end,
        config = function(_, opts)
          require("render-markdown").setup(opts)
          require("configs.render_markdown").after_setup()
        end,
      },
    },
  },

  {
    "nwiizo/codex.nvim",
    event = "VeryLazy",
    cmd = {
      "Codex",
      "CodexOpen",
      "CodexFocus",
      "CodexResume",
      "CodexContinue",
      "CodexAsk",
      "CodexEdit",
      "CodexSendVisual",
      "CodexAdd",
      "CodexStop",
      "CodexStatus",
      "CodexHealth",
    },
    opts = function()
      return require("configs.codex").opts()
    end,
    keys = function()
      return require("configs.codex").keys()
    end,
  },
}
