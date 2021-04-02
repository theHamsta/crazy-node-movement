local parsers = require "nvim-treesitter.parsers"

local M = {}

function M.init()
  require "nvim-treesitter".define_modules {
    node_movement = {
      module_path = "crazy-node-movement.node_movement",
      is_supported = function(lang)
        return parsers.has_parser(lang)
      end,
      keymaps = {
        move_up = "<a-k>",
        move_down = "<a-j>",
        move_left = "<a-h>",
        move_right = "<a-l>",
        swap_left = "<s-a-h>",
        swap_right = "<s-a-l>",
        select_current_node = "<leader><cr>"
      },
      swappable_textobjects = {'@function.outer', '@parameter.inner', '@statement.outer'},
      allow_switch_parents = true,
      allow_next_parent = true,
    }
  }
end

return M
