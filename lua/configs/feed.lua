local M = {}

function M.opts()
  return {
    -- 关掉居中浮层和遮罩。窗口位置在 patch 里改成底部小窗。
    zen = { enabled = false },
    feeds = {
      { "https://www.ithome.com/rss/", name = "IT之家" },
      { "https://www.36kr.com/feed", name = "36氪" },
      { "https://www.ifanr.com/feed", name = "爱范儿" },
      { "https://www.geekpark.net/rss", name = "极客公园" },
      { "https://rss.huxiu.com/", name = "虎嗅" },
      { "https://www.solidot.org/index.rss", name = "Solidot" },
      { "https://www.v2ex.com/index.xml", name = "V2EX" },
      { "https://www.gcores.com/rss", name = "机核" },
      { "https://www.appinn.com/feed/", name = "小众软件" },
      { "https://rsshub.rssforever.com/zhihu/daily", name = "知乎日报" },
      { "https://feed.wallstreetcn.com/", name = "华尔街见闻" },
      { "https://tech.meituan.com/feed/", name = "美团技术" },
      { "https://www.ruanyifeng.com/blog/atom.xml", name = "阮一峰" },
    },
  }
end

function M.pick_source()
  require("feed").setup(M.opts())
  local db = require "feed.db"
  local state = require "feed.state"

  local items = {
    { name = "全部", query = "+unread @2-weeks-ago" },
  }
  local names = {}
  for url, feed in pairs(db.feeds or {}) do
    if type(feed) == "table" then
      names[#names + 1] = { name = feed.title or url, url = url }
    end
  end
  table.sort(names, function(a, b)
    return a.name < b.name
  end)
  for _, feed in ipairs(names) do
    local literal = vim.fn.escape(feed.url, [[\.*~[]^$]])
    items[#items + 1] = {
      name = feed.name,
      query = "=" .. literal .. " +unread @2-weeks-ago",
    }
  end

  vim.ui.select(items, {
    prompt = "订阅源",
    format_item = function(item)
      return item.name
    end,
  }, function(choice)
    if not choice then
      return
    end
    state.query = choice.query
    state.entries = nil
    vim.cmd "Feed index"
  end)
end

local function height()
  return math.min(16, math.max(10, math.floor(vim.o.lines * 0.28)))
end

local function drop_swap(winobj)
  if winobj and winobj.augroup then
    pcall(vim.api.nvim_clear_autocmds, { group = winobj.augroup, event = "BufWinEnter" })
  end
end

local function code_win(exclude)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= exclude and vim.api.nvim_win_get_config(win).relative == "" then
      return win
    end
  end
end

function M.patch()
  -- 36氪的时间是「2026-10-30 10:10:29 +0800」。插件认不出这种格式，
  -- 会把每一篇都记成当月 1 日，于是「最近两周」里一篇都没有。
  local date = require "feed.parser.date"
  if not date._clock_date then
    date._clock_date = true
    local orig = date.parse
    function date.parse(str, kind)
      if type(str) == "string" then
        local y, mo, d, h, mi, s = str:match "^(%d%d%d%d)%-(%d%d)%-(%d%d)[ T](%d%d):(%d%d):(%d%d)"
        if y then
          return os.time {
            year = tonumber(y),
            month = tonumber(mo),
            day = tonumber(d),
            hour = tonumber(h),
            min = tonumber(mi),
            sec = tonumber(s),
          }
        end
      end
      return orig(str, kind)
    end
  end

  local Win = require "feed.ui.window"
  if Win._feed_bottom then
    return
  end
  Win._feed_bottom = true

  local orig_new = Win.new
  local orig_update = Win.update
  local orig_close = Win.close

  function Win:update()
    if self.opts.feed_split and self.win and vim.api.nvim_win_is_valid(self.win) then
      vim.api.nvim_win_set_height(self.win, height())
      return
    end
    orig_update(self)
  end

  function Win:close()
    if self.opts.ignore_float_close then
      self.opts.ignore_float_close = false
      return
    end
    if self.opts.keep_buf then
      local index = require("feed.state").index
      if index and index.buf and vim.api.nvim_buf_is_valid(index.buf) and vim.api.nvim_win_is_valid(index.win) then
        vim.api.nvim_win_set_buf(index.win, index.buf)
        vim.api.nvim_set_current_win(index.win)
      end
      if self.buf and vim.api.nvim_buf_is_valid(self.buf) and (not index or self.buf ~= index.buf) then
        vim.api.nvim_buf_delete(self.buf, { force = true })
      end
      return
    end
    orig_close(self)
  end

  function Win.new(opts, enter)
    opts = opts or {}
    local parent = vim.api.nvim_get_current_win()
    local self = orig_new(opts, enter)
    if opts.is_backdrop then
      return self
    end

    local index = require("feed.state").index
    if opts.buf and index and index.win and vim.api.nvim_win_is_valid(index.win) and index.win ~= self.win then
      -- 插件发现窗口里的 buffer 变了，会把内容换到旁边的大窗。文章要留在小窗里。
      drop_swap(index)
      drop_swap(self)
      vim.api.nvim_win_set_buf(index.win, self.buf)
      vim.api.nvim_set_current_win(index.win)
      self.float_win = self.win
      self.win = index.win
      self.opts.keep_buf = true
      self.opts.feed_split = true
      self.opts.ignore_float_close = true
      if self.float_win and vim.api.nvim_win_is_valid(self.float_win) then
        vim.api.nvim_win_close(self.float_win, true)
      end
      return self
    end

    parent = code_win(self.win) or parent
    if parent and vim.api.nvim_win_is_valid(parent) and parent ~= self.win then
      pcall(vim.api.nvim_win_set_config, self.win, {
        split = "below",
        win = parent,
        height = height(),
      })
      self.opts.feed_split = true
    end
    return self
  end
end

return M
