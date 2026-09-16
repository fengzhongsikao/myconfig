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
        local win = vim.api.nvim_get_current_win()
        if not vim.api.nvim_win_is_valid(win) or vim.env.TERM ~= "xterm-kitty" then
          return
        end
        if current_image then
          pcall(function()
            current_image:clear()
          end)
          current_image = nil
        end

        local w, h = image_size(win)
        local x = math.floor((vim.api.nvim_win_get_width(win) - w) / 2)
        current_image = require("image").from_file(img_path, {
          window = win,
          buffer = buf,
          x = x,
          y = 4,
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
          vim.defer_fn(function()
            render_image(event.buf)
          end, 50)
        end,
      })

      -- 窗口缩放时清除旧图并按新尺寸重新渲染
      vim.api.nvim_create_autocmd("VimResized", {
        group = dashboard_group,
        callback = function()
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.bo[buf].filetype == "dashboard" then
              render_image(buf)
            end
          end
        end,
      })

      -- 5. 离开 dashboard 时清除图片，防止残影
      vim.api.nvim_create_autocmd("BufLeave", {
        group = dashboard_group,
        callback = function(event)
          if vim.bo[event.buf].filetype == "dashboard" then
            if current_image then
              pcall(function()
                current_image:clear()
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
