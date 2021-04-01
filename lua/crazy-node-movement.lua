local parsers = require "nvim-treesitter.parsers"

local M = {}

function M.init()
  require "nvim-treesitter".define_modules {
    node_movement = {
      module_path = "crazy-node-movement.internal",
      is_supported = function(lang)
        return parsers.has_parser(lang)
      end,
      keymaps = {
        move_up = "<a-k>",
        move_down = "<a-j>",
        move_left = "<a-h>",
        move_right = "<a-l>",
        swap_up = "<s-a-k>",
        swap_down = "<s-a-j>",
        swap_left = "<s-a-h>",
        swap_right = "<s-a-l>",
        select_current_node = "<leader>ff"
      }
    }
  }
end

return M
