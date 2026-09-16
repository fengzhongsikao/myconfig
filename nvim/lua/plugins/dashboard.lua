return {
  { "folke/snacks.nvim", opts = { dashboard = { enabled = false } } },
  {
    "nvimdev/dashboard-nvim",
    lazy = false,
    opts = function()
      -- 1. 配置图片路径（放在 ~/.config/nvim/ 下）
      local img_path = vim.fn.stdpath("config") .. "/ndqk.png"
      local img_width = 40 -- 图片最大显示宽度
      local img_height = 20 -- 图片最大显示高度

      -- 按当前窗口尺寸计算图片实际宽高（保持 2:1 比例，不超出窗口）
      local function image_size(win)
        local win_width = vim.api.nvim_win_get_width(win)
        local win_height = vim.api.nvim_win_get_height(win)
        local w = math.min(img_width, math.floor(win_width * 0.8))
        local h = math.min(img_height, math.floor(win_height * 0.5))
        -- 取较小的缩放比例，保持宽高比
        local scale = math.min(w / img_width, h / img_height)
        return math.floor(img_width * scale), math.floor(img_height * scale)
      end

      -- 渲染（或按新窗口尺寸重渲染）图片
      local current_image = nil
      local function render_image(buf)
        if vim.env.TERM ~= "xterm-kitty" then
          return
        end
        -- 找到显示该 buffer 的窗口（光标可能已不在 dashboard 窗口）
        local win
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_buf(w) == buf then
            win = w
            break
          end
        end
        if not win then
          return
        end
        -- 清掉所有旧图（含引用已丢失的残留实例），避免出现多张/残影
        pcall(function()
          require("image").clear()
        end)
        current_image = nil

        local w, h = image_size(win)

        -- 不改任何 buffer 文字（快捷键是 extmark，重写行会破坏布局）。
        -- 图片锚定到菜单：header 区全是空白，第一个非空行即菜单首项，
        -- 图片水平对齐菜单块（含 eol 上的快捷键 extmark，约 3 列）、底边贴着菜单上方
        local anchor_line, menu_col, anchor_width
        for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
          if l:match("%S") then
            local leading = l:match("^%s*"):len()
            anchor_line = i
            menu_col = leading -- 前导空格数即内容的屏幕列（0 起，无水平滚动）
            anchor_width = vim.fn.strdisplaywidth(l) - leading + 3
            break
          end
        end
        if not anchor_line then
          return
        end

        -- 实测菜单首行在屏幕上的行号（自动含滚动）
        local menu_row
        local cursor = vim.api.nvim_win_get_cursor(win)
        vim.api.nvim_win_call(win, function()
          vim.api.nvim_win_set_cursor(win, { anchor_line, 0 })
          menu_row = vim.fn.winline() - 1 -- 0 起
        end)
        vim.api.nvim_win_set_cursor(win, cursor)

        local x = math.max(0, menu_col + math.floor((anchor_width - w) / 2))
        local y = math.max(0, menu_row - 2 - h) -- 底边留在菜单上方两行空行处
        current_image = require("image").from_file(img_path, {
          window = win,
          buffer = buf,
          x = x,
          y = y,
          width = w,
          height = h,
        })
        current_image:render()
      end

      -- 2. 生成空白行，给图片腾出悬浮空间
      local logo_lines = {}
      for _ = 1, img_height do
        table.insert(logo_lines, string.rep(" ", img_width))
      end
      -- 在图片上方留出 4 行空白
      logo_lines = vim.list_extend({ "", "", "", "" }, logo_lines)
      -- 在图片下方留出空白
      table.insert(logo_lines, "")
      table.insert(logo_lines, "")

      -- 3. Dashboard 配置
      local opts = {
        theme = "doom",
        hide = {
          statusline = false,
        },
        config = {
          header = logo_lines,
          -- stylua: ignore
          center = {
            { action = 'lua LazyVim.pick()()',                           desc = " Find File",       icon = " ", key = "f" },
            { action = "ene | startinsert",                              desc = " New File",        icon = " ", key = "n" },
            { action = 'lua LazyVim.pick("oldfiles")()',                 desc = " Recent Files",    icon = " ", key = "r" },
            { action = 'lua LazyVim.pick("live_grep")()',                desc = " Find Text",       icon = " ", key = "g" },
            { action = 'lua LazyVim.pick.config_files()()',              desc = " Config",          icon = " ", key = "c" },
            { action = 'lua require("persistence").load()',              desc = " Restore Session", icon = " ", key = "s" },
            { action = "LazyExtras",                                     desc = " Lazy Extras",     icon = " ", key = "x" },
            { action = "Lazy",                                           desc = " Lazy",            icon = "󰒲 ", key = "l" },
            { action = function() vim.api.nvim_input("<cmd>qa<cr>") end, desc = " Quit",            icon = " ", key = "q" },
          },
          footer = function()
            local stats = require("lazy").stats()
            local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
            return { "⚡ Neovim loaded " .. stats.loaded .. "/" .. stats.count .. " plugins in " .. ms .. "ms" }
          end,
        },
      }

      for _, button in ipairs(opts.config.center) do
        button.desc = button.desc .. string.rep(" ", 43 - #button.desc)
        button.key_format = "  %s"
      end

      -- open dashboard after closing lazy
      if vim.o.filetype == "lazy" then
        vim.api.nvim_create_autocmd("WinClosed", {
          pattern = tostring(vim.api.nvim_get_current_win()),
          once = true,
          callback = function()
            vim.schedule(function()
              vim.api.nvim_exec_autocmds("UIEnter", { group = "dashboard" })
            end)
          end,
        })
      end

      -- 4. 监听 Dashboard 打开，渲染真实图片
      local dashboard_group = vim.api.nvim_create_augroup("dashboard_image_render", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = dashboard_group,
        pattern = "dashboard",
        callback = function(event)
          local buf = event.buf
          -- dashboard 在 VimResized 时会自己重排 buffer；监听其行变化，
          -- 每次重排后跟着重渲染图片，避免用到过期的菜单位置
          if not vim.b[buf].image_attached then
            vim.b[buf].image_attached = true
            vim.api.nvim_buf_attach(buf, false, {
              on_lines = function()
                vim.defer_fn(function()
                  if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "dashboard" then
                    render_image(buf)
                  end
                end, 10)
              end,
            })
          end
          vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(buf) then
              render_image(buf)
            end
          end, 50)
        end,
      })

      -- 兜底：dashboard 未重排时（旧版行为）窗口缩放后自行重渲染
      vim.api.nvim_create_autocmd("VimResized", {
        group = dashboard_group,
        callback = function()
          vim.defer_fn(function()
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
              if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "dashboard" then
                render_image(buf)
              end
            end
          end, 150)
        end,
      })

      -- dashboard buffer 被删除时彻底清图，防止残影
      vim.api.nvim_create_autocmd("BufWipeout", {
        group = dashboard_group,
        callback = function(event)
          if vim.bo[event.buf].filetype == "dashboard" then
            pcall(function()
              require("image").clear()
            end)
            current_image = nil
          end
        end,
      })

      -- 5. 光标离开 dashboard 时：仍显示在其他窗口就重绘，否则清除防残影
      vim.api.nvim_create_autocmd("BufLeave", {
        group = dashboard_group,
        callback = function(event)
          if vim.bo[event.buf].filetype == "dashboard" then
            local visible = false
            for _, w in ipairs(vim.api.nvim_list_wins()) do
              if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_buf(w) == event.buf then
                visible = true
                break
              end
            end
            if visible then
              render_image(event.buf)
            else
              pcall(function()
                require("image").clear()
              end)
              current_image = nil
            end
          end
        end,
      })

      return opts
    end,
  },
}
