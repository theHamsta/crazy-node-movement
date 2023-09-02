

# crazy-node-movement

Move along the parsered tree-sitter syntax tree. Not sure if that is a good idea 😄.
Only works well with languages with a well-structured hierachical AST.

![crazy-movement](https://user-images.githubusercontent.com/7189118/113417624-14fe1100-93c4-11eb-86bf-9d7db62f329b.gif)

## Installation

```vim
Plug 'theHamsta/crazy-node-movement'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-treesitter/nvim-treesitter-textobjects'
```

The configuration is like any other nvim-treesitter module.

```lua
require "nvim-treesitter.configs".setup {
  node_movement = {
    enable = true,
    keymaps = {
      move_up = "<a-k>",
      move_down = "<a-j>",
      move_left = "<a-h>",
      move_right = "<a-l>",
      swap_left = "<s-a-h>", -- will only swap when one of "swappable_textobjects" is selected
      swap_right = "<s-a-l>",
      select_current_node = "<leader><Cr>",
    },
    swappable_textobjects = {'@function.outer', '@parameter.inner', '@statement.outer'},
    allow_switch_parents = true, -- more craziness by switching parents while staying on the same level, false prevents you from accidentally jumping out of a function
    allow_next_parent = true, -- more craziness by going up one level if next node does not have children
  }
}
```

## Disclaimer

Please don't expect too much from this. This is just an experiment. Will fix swapping speed in nvim-treesitter-textobjects soon.

