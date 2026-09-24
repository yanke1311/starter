-- 类似 VS Code sticky scroll：按窗口第一行算，被挡住的最外层函数签名钉在顶部。
-- cursor 模式只钉光标所在函数。

return {
  enable = true,
  max_lines = 4,
  min_window_height = 12,
  line_numbers = true,
  multiline_threshold = 4,
  trim_scope = "outer",
  mode = "topline",
  separator = "─",
  zindex = 20,
}
