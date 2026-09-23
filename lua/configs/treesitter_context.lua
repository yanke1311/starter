-- 类似 VS Code sticky scroll：光标还在函数体内、签名滚出视口时钉在窗口顶部。

return {
  enable = true,
  max_lines = 4,
  min_window_height = 12,
  line_numbers = true,
  multiline_threshold = 4,
  trim_scope = "outer",
  mode = "cursor",
  separator = "─",
  zindex = 20,
}
