local api = vim.api
local parsers = require'nvim-treesitter.parsers'
local ts_utils = require'nvim-treesitter.ts_utils'
local caching = require'nvim-treesitter.caching'
local shared = require'nvim-treesitter.textobjects.shared'
local textobject_swap = require'nvim-treesitter.textobjects.swap'
local cmd = api.nvim_command
local M = {}

local hl_namespace = api.nvim_create_namespace('crazy-node-movement')

M.current_node = {}
local swappable_textobjects = {}
local favorite_child = caching.create_buffer_cache()

function M.clear_highlights(buf)
  api.nvim_buf_clear_namespace(buf, hl_namespace, 0, -1)
end

local function current_node_ok(buf)
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  line = line - 1
  local pos = M.current_node[buf] and {M.current_node[buf]:start()}
  return pos and line == pos[1] and col == pos[2]
end

function M.maybe_clear_highlights(buf)
  if not current_node_ok(buf) then
    api.nvim_buf_clear_namespace(buf, hl_namespace, 0, -1)
  end
end

function M.do_node_movement(kind, swap)
  local buf = vim.api.nvim_get_current_buf()

  local current_node = M.current_node[buf]

  if not current_node_ok(buf) then
    current_node = ts_utils.get_node_at_cursor()
  end
  local destination_node

  if parsers.has_parser() then

    if kind == 'up' then
      destination_node = current_node:parent()
      if destination_node then
        favorite_child.set(destination_node:id(), buf, current_node)
      end
    elseif kind == 'down' then
      if current_node:named_child_count() > 0 then
        destination_node = favorite_child.get(current_node:id(), buf) or current_node:named_child(0)
      else
        local next_node = ts_utils.get_next_node(current_node)
        if next_node and next_node:named_child_count() > 0 then
          destination_node = next_node:named_child(0)
        end
      end
    elseif kind == 'left' then
      destination_node = ts_utils.get_previous_node(current_node, true, true)
    elseif kind == 'right' then
      destination_node = ts_utils.get_next_node(current_node, true, true)
    end
    M.current_node[buf] = destination_node or current_node
  end

  if destination_node then
    if swap then
      destination_node = nil
      for _, object_type in ipairs(swappable_textobjects) do
        local _, _, textobject = shared.textobject_at_point(object_type)
        if type(current_node) == 'userdata' and type(textobject) == 'userdata'
            and textobject:id() == current_node:id() then
          if kind == 'left' then
            textobject_swap.swap_previous(object_type)
          elseif kind == 'right' then
            textobject_swap.swap_next(object_type)
          end
          parsers.get_parser():parse()
          local _, _, textobject = shared.textobject_at_point(object_type)
          destination_node = textobject
          M.current_node[buf] = textobject
          break
        end
      end
    else
      ts_utils.goto_node(destination_node)
    end
    M.clear_highlights(buf)
    ts_utils.highlight_node(destination_node, buf, hl_namespace, 'CrazyNodeMovementCurrent')
  end
end

M.move_up = function() M.do_node_movement('up') end
M.move_down = function() M.do_node_movement('down') end
M.move_left = function() M.do_node_movement('left') end
M.move_right = function() M.do_node_movement('right') end

M.swap_left = function() M.do_node_movement('left', true) end
M.swap_right = function() M.do_node_movement('right', true) end

M.select_current_node = function()
  local buf = vim.api.nvim_get_current_buf()
  local current_node = M.current_node[buf]
  if not current_node_ok(buf) then
    current_node = ts_utils.get_node_at_cursor()
  end
  if current_node then
    ts_utils.update_selection(buf, current_node)
  end
end

function M.attach(bufnr)
  local buf = bufnr or api.nvim_get_current_buf()

  local config = require'nvim-treesitter.configs'.get_module('node_movement')
  swappable_textobjects = config.swappable_textobjects
  for funcname, mapping in pairs(config.keymaps) do
    api.nvim_buf_set_keymap(buf, 'n', mapping,
      string.format(":lua require'crazy-node-movement.node_movement'.%s()<CR>", funcname), { silent = true })
  end
  cmd(string.format('augroup CrazyNodeMovementCurrent_%d', bufnr))
  cmd 'au!'
  -- luacheck: push ignore 631
  cmd(string.format([[autocmd CursorMoved <buffer=%d> lua require'crazy-node-movement.node_movement'.maybe_clear_highlights(%d)]], bufnr, bufnr))
  -- luacheck: pop
  cmd 'augroup END'
end

function M.detach(bufnr)
  local buf = bufnr or api.nvim_get_current_buf()

  M.clear_highlights(bufnr)
  vim.cmd(string.format('autocmd! CrazyNodeMovementCurrent_%d CursorMoved', bufnr))
  local config = require'nvim-treesitter.configs'.get_module('node_movement')
  for _, mapping in pairs(config.keymaps) do
    api.nvim_buf_del_keymap(buf, 'n', mapping)
  end
end

return M
