local api = vim.api
local parsers = require'nvim-treesitter.parsers'
local ts_utils = require'nvim-treesitter.ts_utils'
local M = {}

M.NodeMovementKind = {
  up = 'up',
  down = 'down',
  left = 'left',
  right = 'right',
}

M.current_node = {}

M.do_node_movement = function(kind)
  local buf = vim.api.nvim_get_current_buf()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))

  local current_node = M.current_node[buf]

  if current_node then
    local node_line, node_col = current_node:start()
    if line-1 ~= node_line or  col-1 ~= node_col then
      current_node = nil
    end
  end
  local destination_node

  if parsers.has_parser() then
    if not current_node then
      current_node = ts_utils.get_node_at_cursor()
    end

    if kind == M.NodeMovementKind.up then
       destination_node = current_node:parent()
    elseif kind == M.NodeMovementKind.down then
      if current_node:named_child_count() > 0 then
        destination_node = current_node:named_child(0)
      else
        local next_node = ts_utils.get_next_node(current_node)
        if next_node and next_node:named_child_count() > 0 then
          destination_node = next_node:named_child(0)
        end
      end
    elseif kind == M.NodeMovementKind.left then
      destination_node = ts_utils.get_previous_node(current_node, true, true)
    elseif kind == M.NodeMovementKind.right then
      destination_node = ts_utils.get_next_node(current_node, true, true)
    end
    M.current_node[buf] = destination_node or current_node
  end

  if destination_node then
    ts_utils.goto_node(destination_node)
  end
end

M.move_up = function() M.do_node_movement(M.NodeMovementKind.up) end
M.move_down = function() M.do_node_movement(M.NodeMovementKind.down) end
M.move_left = function() M.do_node_movement(M.NodeMovementKind.left) end
M.move_right = function() M.do_node_movement(M.NodeMovementKind.right) end

M.select_current_node = function()
  local buf, line, col = unpack(vim.fn.getpos("."))
  local current_node = M.current_node[buf]
  if current_node then
    local node_line, node_col = current_node:start()
    if line-1 ~= node_line or  col-1 ~= node_col then
      current_node = nil
    end
  end
  if not current_node then
    local root = parsers.get_parser():parse():root()
    current_node = root:named_descendant_for_range(line-1, col-1, line-1, col)
  end
  ts_utils.node_range_to_vim(current_node)
end

function M.attach(bufnr)
  local buf = bufnr or api.nvim_get_current_buf()

  local config = require'nvim-treesitter.configs'.get_module('node_movement')
  for funcname, mapping in pairs(config.keymaps) do
    api.nvim_buf_set_keymap(buf, 'n', mapping,
      string.format(":lua require'nvim-treesitter.node_movement'.%s()<CR>", funcname), { silent = true })
  end
end

function M.detach(bufnr)
  local buf = bufnr or api.nvim_get_current_buf()

  local config = require'nvim-treesitter.configs'.get_module('node_movement')
  for _, mapping in pairs(config.keymaps) do
    api.nvim_buf_del_keymap(buf, 'n', mapping)
  end
end

return M
