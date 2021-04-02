

# crazy-node-movement

Move along the parsered tree-sitter syntax tree. Not sure if that is a good idea 😄.

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
  }
}
```

## Disclaimer

Please don't expect too much from this. This is just an experiment.

