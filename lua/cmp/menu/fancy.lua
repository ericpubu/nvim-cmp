local keymap = require('cmp.utils.keymap')
local config = require('cmp.config')
local autocmd = require('cmp.utils.autocmd')
local window = require "cmp.utils.window"

local fancy = {}

fancy.ns = vim.api.nvim_create_namespace('cmp.menu.fancy')

fancy.new = function()
  local self = setmetatable({}, { __index = fancy })
  self.menu_win = window.new()
  self.menu_win:option('conceallevel', 2)
  self.menu_win:option('concealcursor', 'n')
  self.menu_win:option('foldenable', false)
  self.menu_win:option('wrap', true)
  self.menu_win:option('scrolloff', 0)
  self.menu_win:option('winhighlight', 'Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel')
  self.offset = -1
  self.items = {}
  self.marks = {}

  autocmd.subscribe('InsertCharPre', function()
    if self:visible() then
      self.menu_win:option('cursorline', false)
      vim.api.nvim_win_set_cursor(self.menu_win.win, { 1, 0 })
    end
  end)

  vim.api.nvim_set_decoration_provider(fancy.ns, {
    on_win = function(_, winid)
      return winid == self.menu_win.win
    end,
    on_line = function(_, winid, bufnr, row)
      if winid == self.menu_win.win then
        local mark = self.marks[row + 1]
        vim.api.nvim_buf_set_extmark(bufnr, fancy.ns, row, mark[1][1][1], {
          end_line = row,
          end_col = mark[1][1][2],
          hl_group = mark[1][2],
          ephemeral = true,
        })
        vim.api.nvim_buf_set_extmark(bufnr, fancy.ns, row, mark[2][1][1], {
          end_line = row,
          end_col = mark[2][1][2],
          hl_group = mark[2][2],
          ephemeral = true,
        })
        vim.api.nvim_buf_set_extmark(bufnr, fancy.ns, row, mark[3][1][1], {
          end_line = row,
          end_col = mark[3][1][2],
          hl_group = mark[3][2],
          ephemeral = true,
        })
        local item = self.items[row + 1]
        for _, m in ipairs(item.matches or {}) do
          vim.api.nvim_buf_set_extmark(bufnr, fancy.ns, row, m.word_match_start, {
            end_line = row,
            end_col = m.word_match_end + 1,
            hl_group = 'Normal',
            hl_mode = 'replace',
            ephemeral = true,
          })
        end
      end
    end
  })

  return self
end

fancy.show = function(self, offset, items)
  self.offset = offset
  self.items = items
  self.marks = {}

  if #items > 0 then
    local words = { bytes = 0, items = {} }
    for i, item in ipairs(items) do
      words.items[i] = ' ' .. (item.abbr or item.word)
      words.bytes = math.max(words.bytes, #words.items[i])
    end
    local kinds = { bytes = 0, items = {} }
    for i, item in ipairs(items) do
      kinds.items[i] = (item.kind or '')
      kinds.bytes = math.max(kinds.bytes, #kinds.items[i])
    end
    local menus = { bytes = 0, items = {} }
    for i, item in ipairs(items) do
      menus.items[i] = (item.menu or '')
      menus.bytes = math.max(menus.bytes, #menus.items[i])
    end

    local lines = {}
    local width = 1
    for i = 1, #items do
      local word_part = words.items[i] .. string.rep(' ', 1 + words.bytes - #words.items[i])
      local kind_part = kinds.items[i] .. string.rep(' ', 1 + kinds.bytes - #kinds.items[i])
      local menu_part = menus.items[i] .. string.rep(' ', 1 + menus.bytes - #menus.items[i])
      lines[i] = string.format('%s%s%s', word_part, kind_part, menu_part)
      self.marks[i] = {
        { { 0, #words.items[i] }, 'Comment' },
        { { #word_part, #word_part + #kinds.items[i] }, 'Special' },
        { { #word_part + #kind_part, #word_part + #kind_part + #menus.items[i] }, 'Comment' },
      }
      width = math.max(#lines[i], width)
    end

    local height = #items
    height = math.min(height, vim.api.nvim_get_option('pumheight') or #items)
    height = math.min(height, (vim.o.lines - 1) - vim.fn.winline() - 1)

    vim.api.nvim_buf_set_lines(self.menu_win.buf, 0, -1, false, lines)
    self.menu_win:open({
      relative = 'editor',
      style = 'minimal',
      row = vim.fn.screenrow(),
      col = vim.fn.screencol() - 1,
      width = width,
      height = height,
    })
    vim.api.nvim_win_set_cursor(self.menu_win.win, { 1, 0 })
    self.menu_win:option('cursorline', false)
  else
    self:hide()
  end
  vim.cmd [[doautocmd CompleteChanged]]
end

fancy.hide = function(self)
  self.menu_win:close()
end

fancy.visible = function(self)
  return self.menu_win:visible()
end

fancy.info = function(self)
  return self.menu_win:info()
end

fancy.select_next_item = function(self)
  if self.menu_win:visible() then
    local cursor = vim.api.nvim_win_get_cursor(self.menu_win.win)[1]
    local word = self.prefix
    if not self.menu_win:option('cursorline') then
      self.prefix = string.sub(vim.api.nvim_get_current_line(), self.offset, vim.api.nvim_win_get_cursor(0)[2])
      self.menu_win:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.menu_win.win, { 1, 0 })
      word = self.items[1].word
    elseif cursor == #self.items then
      self.menu_win:option('cursorline', false)
      vim.api.nvim_win_set_cursor(self.menu_win.win, { 1, 0 })
    else
      self.menu_win:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.menu_win.win, { cursor + 1, 0 })
      word = self.items[cursor + 1].word
    end
    self:insert(word)
    self.menu_win:update()
    vim.cmd [[doautocmd CompleteChanged]]
  end
end

fancy.select_prev_item = function(self)
  if self.menu_win:visible() then
    local cursor = vim.api.nvim_win_get_cursor(self.menu_win.win)[1]
    local word = self.prefix
    if not self.menu_win:option('cursorline') then
      self.prefix = string.sub(vim.api.nvim_get_current_line(), self.offset, vim.api.nvim_win_get_cursor(0)[2])
      self.menu_win:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.menu_win.win, { #self.items, 0 })
      word = self.items[#self.items].word
    elseif cursor == 1 then
      self.menu_win:option('cursorline', false)
      vim.api.nvim_win_set_cursor(self.menu_win.win, { 1, 0 })
    else
      self.menu_win:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.menu_win.win, { cursor - 1, 0 })
      word = self.items[cursor - 1].word
    end
    self:insert(word)
    self.menu_win:update()
    vim.cmd [[doautocmd CompleteChanged]]
  end
end

fancy.is_active = function(self)
  return not not self:get_selected_item()
end

fancy.get_first_item = function(self)
  if self.menu_win:visible() then
    return self.items[1]
  end
end

fancy.get_selected_item = function(self)
  if self.menu_win:visible() and self.menu_win:option('cursorline') then
    return self.items[vim.api.nvim_win_get_cursor(self.menu_win.win)[1]]
  end
end

fancy.insert = function(self, word)
  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_text(0, cursor[1] - 1, self.offset - 1, cursor[1] - 1, cursor[2], { word })
  vim.api.nvim_win_set_cursor(0, { cursor[1], self.offset + #word - 1 })
end

return fancy