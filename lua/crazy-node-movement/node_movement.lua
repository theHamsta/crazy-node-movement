local api = vim.api
local parsers = require "nvim-treesitter.parsers"
local ts_utils = require "nvim-treesitter.ts_utils"
local caching = require "nvim-treesitter.caching"
local shared = require "nvim-treesitter.textobjects.shared"
local textobject_swap = require "nvim-treesitter.textobjects.swap"
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local M = {}
M.current_node = {}

-- stylua: ignore start
local hl_namespace = api.nvim_create_namespace "crazy-node-movement"
local hl_group     = "CrazyNodeMovementCurrent"

local au_group_name= "CrazyNodeMovement"

local keyseq_MLA   = vim.api.nvim_replace_termcodes("m<", true, false, true) -- Set left '< mark
local keyseq_MRA   = vim.api.nvim_replace_termcodes("m>", true, false, true) -- Set right '> mark
-- stylua: ignore start

local swappable_textobjects = {}
local tick = {}
local favorite_child = caching.create_buffer_cache()
local allow_switch_parents = true
local allow_next_parent = true

function M.clear_highlights(buf)
  api.nvim_buf_clear_namespace(buf, hl_namespace, 0, -1)
end

function M.highlight_current_node(tsNode, buf, config)
  M.clear_highlights(buf)
  api.nvim_set_hl_ns(hl_namespace)
  if config.highlight.group then
    -- NOTE: This call misbehaves when :tabnew is called from vim.cmd...
    -- api.nvim_set_hl(hl_namespace, hl_group, { link = config.highlight.group })
      vim.cmd("highlight link " .. hl_group .. " " .. config.highlight.group)
  else
    api.nvim_set_hl(hl_namespace, hl_group, { fg  = config.highlight.fg })
  end
  ts_utils.highlight_node(tsNode, buf, hl_namespace, hl_group)
end

local function current_node_ok(buf)
  local new_tick = api.nvim_buf_get_changedtick(buf)
  if not tick[buf] or new_tick > tick[buf] then
    return false
  end
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  line = line - 1
  local pos = M.current_node[buf] and { M.current_node[buf]:start() }
  return pos and line == pos[1] and col == pos[2]
end

function M.maybe_clear_highlights(buf)
  if not current_node_ok(buf) then
    api.nvim_buf_clear_namespace(buf, hl_namespace, 0, -1)
  end
end

function M.do_node_movement(kind, swap, selectNode)
  local buf = vim.api.nvim_get_current_buf()
  local config = require("nvim-treesitter.configs").get_module "node_movement"
  local current_node = M.current_node[buf]

  if not current_node_ok(buf) then
    current_node = ts_utils.get_node_at_cursor()
  end
  local destination_node

  if parsers.has_parser() and current_node then
    if kind == "up" then
      destination_node = current_node:parent()
      if destination_node then
        favorite_child.set(destination_node:id(), buf, current_node)
      else
        local current_tree = parsers.get_parser():language_for_range { current_node:range() }
        local parent_tree = current_tree and current_tree.parent and current_tree:parent()
        destination_node = parent_tree
          and parent_tree
            :tree_for_range({ current_node:range() }, false)
            :root()
            :named_descendant_for_range(current_node:range())
      end
    elseif kind == "down" then
      if current_node:named_child_count() > 0 then
        destination_node = favorite_child.get(current_node:id(), buf) or current_node:named_child(0)
      else
        parsers.get_parser():for_each_tree(function(tree, _)
          if not destination_node then
            local range = { tree:root():range() }
            if
              vim.treesitter.is_in_node_range(current_node, range[1], range[2])
              and tree:root():named_child_count() > 0
            then
              destination_node = tree:root()
              destination_node = favorite_child.get(destination_node:id(), buf) or destination_node:named_child(0)
            end
          end
        end)
        if not destination_node then
          local next_node = ts_utils.get_next_node(current_node)
          if next_node and next_node:named_child_count() > 0 then
            destination_node = next_node:named_child(0)
          end
        end
      end
    elseif kind == "left" then
      destination_node = ts_utils.get_previous_node(current_node, allow_switch_parents, allow_next_parent)
    elseif kind == "right" then
      destination_node = ts_utils.get_next_node(current_node, allow_switch_parents, allow_next_parent)
    end
    M.current_node[buf] = destination_node or current_node
    tick[buf] = api.nvim_buf_get_changedtick(buf)
  end

  if destination_node then
    if swap then
      if kind == "up" then
        local destination_range = ts_utils.node_to_lsp_range(destination_node)
        local replacement = vim.treesitter.get_node_text(current_node, buf)
        vim.lsp.util.apply_text_edits({ { range = destination_range, newText = replacement } }, buf, "utf8")
        parsers.get_parser():parse()
        api.nvim_win_set_cursor(api.nvim_get_current_win(), {
          destination_range.start.line + 1,
          destination_range.start.character,
        })
        local new_node = ts_utils.get_node_at_cursor()
        local old_length = ts_utils.node_length(current_node)
        while new_node and ts_utils.node_length(new_node) < old_length do
          new_node = new_node:parent()
        end
      else
        destination_node = nil
        for _, object_type in ipairs(swappable_textobjects) do
          local _, _, textobject = shared.textobject_at_point(object_type)
          if
            type(current_node) == "userdata"
            and type(textobject) == "userdata"
            and textobject:id() == current_node:id()
          then
            if kind == "left" then
              textobject_swap.swap_previous(object_type)
            elseif kind == "right" then
              textobject_swap.swap_next(object_type)
            end
            parsers.get_parser():parse()
            local _, _, textobject = shared.textobject_at_point(object_type)
            destination_node = textobject
            M.current_node[buf] = textobject
            tick[buf] = api.nvim_buf_get_changedtick(buf)
            break
          end
        end
      end
    else
      ts_utils.goto_node(destination_node)
    end

    print(("debug: %s: buf entering"):format(debug.getinfo(1).source))
    print(vim.inspect(buf))
    if selectNode then
      M.select_current_node(destination_node, buf)
    else
      M.highlight_current_node(destination_node, buf, config)
    end
  end
end

M.move_up = function()
  M.do_node_movement "up"
end
M.move_down = function()
  M.do_node_movement "down"
end
M.move_left = function()
  M.do_node_movement "left"
end
M.move_right = function()
  M.do_node_movement "right"
end

M.swap_up = function()
  M.do_node_movement("up", true)
end
M.swap_left = function()
  M.do_node_movement("left", true)
end
M.swap_right = function()
  M.do_node_movement("right", true)
end

-- stylua: ignore start
-- Export select_up, select_down, select_left, select_right
local select_to_move_map = {
  select_up    = "up",
  select_down  = "down",
  select_left  = "left",
  select_right = "right"
}
for select_action, move_action in pairs(select_to_move_map) do
  M[select_action] = function()
      M.do_node_movement(move_action, false, true)
  end
end
-- stylua: ignore end

M.select_current_node = function(destination_node, buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local current_node = destination_node or M.current_node[buf]
  if not (destination_node or current_node_ok(buf)) then
    current_node = ts_utils.get_node_at_cursor()
    M.current_node[buf] = current_node
  end
  if current_node then
    local start_row, start_col, end_row, end_col = ts_utils.get_vim_range({
      vim.treesitter.get_node_range(current_node),
    }, buf)

    M.clear_highlights(buf)
    -- NOTE: Ordering is important: ALWAYS put the cursor at leftmost col!
    vim.api.nvim_win_set_cursor(0, { end_row, end_col - 1 })
    vim.api.nvim_feedkeys(keyseq_MLA, "x", false)
    vim.api.nvim_win_set_cursor(0, { start_row, start_col - 1 })
    vim.api.nvim_feedkeys(keyseq_MRA, "x", false)
    vim.cmd [[noautocmd normal! gv]]
  end
end

-- TODO: Move to plugin/crazy-node-movement.lua
function M.attach(bufnr)
  local buf = bufnr or api.nvim_get_current_buf()

  local config = require("nvim-treesitter.configs").get_module "node_movement"
  config._attachedMappings = {}
  swappable_textobjects = config.swappable_textobjects
  allow_switch_parents = config.allow_switch_parents
  allow_next_parent = config.allow_next_parent
  for funcname, mapping in pairs(config.keymaps) do
    if string.match(funcname, "move") and mapping ~= "" then
      table.insert(config._attachedMappings, mapping)
      api.nvim_buf_set_keymap(buf, "n", mapping, "", {
        silent = true,
        callback = M[funcname],
      })
    end
    if string.match(funcname, "select") and mapping ~= "" then
      table.insert(config._attachedMappings, mapping)
      api.nvim_buf_set_keymap(buf, "v", mapping, "", {
        silent = true,
        callback = M[funcname],
      })
    end
  end
  if config.keymaps.select_current_node and mapping ~= "" then
    api.nvim_buf_set_keymap(buf, "o", config.keymaps.select_current_node, "", {
      silent = true,
      callback = M.select_current_node,
    })
  end

  local au_group_id  = augroup(au_group_name, { clear = false })

  autocmd({
    "CursorMoved",
  }, {
    group = au_group_id,
    buffer = buf,
    callback = function(opts)
      M.maybe_clear_highlights(opts.buf)
    end,
  })

end

function M.detach(buf)
  local buf = buf or api.nvim_get_current_buf()

  M.clear_highlights(buf)
  vim.api.nvim_del_augroup_by_name(au_group_name)
  local config = require("nvim-treesitter.configs").get_module "node_movement"
  for _, mapping in ipairs(config._attachedMappings) do
    local bufferHasMapping = vim.fn.mapcheck(mapping, "n") ~= ""
    if bufferHasMapping then
      api.nvim_buf_del_keymap(buf, "n", mapping)
    end
  end
  config._attachedMappings = nil
end

return M
