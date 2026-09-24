-- 只覆盖实际使用的选项；其余使用 cmake-tools 默认值。
return {
  cmake_use_preset = true,
  cmake_regenerate_on_save = true,
  cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" },
  cmake_build_directory = "out/${variant:buildType}",
  cmake_compile_commands_options = { action = "soft_link" },
  cmake_dap_configuration = {
    name = "CMake",
    type = "codelldb",
    request = "launch",
    stopOnEntry = false,
    terminal = "integrated",
  },
  cmake_executor = {
    name = "quickfix",
    opts = {
      show = "always",
      position = "belowright",
      size = 10,
      encoding = "utf-8",
      auto_close_when_success = true,
    },
  },
  cmake_runner = {
    name = "terminal",
    opts = {
      name = "Main Terminal",
      prefix_name = "[CMakeTools]: ",
      split_direction = "horizontal",
      split_size = 11,
      single_terminal_per_instance = true,
      single_terminal_per_tab = true,
      keep_terminal_static_location = true,
      auto_resize = true,
      start_insert = false,
      -- 运行后保留编辑窗口焦点，并避开插件重建终端时的无效窗口编号错误。
      focus = false,
      do_not_add_newline = false,
    },
  },
  cmake_virtual_text_support = true,
}
