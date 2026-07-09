local t = require("tests.minitest")

t.test("native paste feeds p or P", function()
  t.reset("yankdown.native")
  local calls = {}
  local old_feedkeys, old_replace = vim.api.nvim_feedkeys, vim.api.nvim_replace_termcodes
  vim.api.nvim_replace_termcodes = function(keys) return keys end
  vim.api.nvim_feedkeys = function(keys, mode) table.insert(calls, { keys = keys, mode = mode }) end

  local native = require("yankdown.native")
  native.paste("after")
  native.paste("before")

  vim.api.nvim_feedkeys = old_feedkeys
  vim.api.nvim_replace_termcodes = old_replace
  t.eq(calls[1].keys, "p")
  t.eq(calls[2].keys, "P")
end)

t.test("non-markdown buffer uses native paste", function()
  t.reset("yankdown.paste")
  package.loaded["yankdown.native"] = {
    paste = function(direction) _G.__native_direction = direction end,
  }
  vim.bo.filetype = "lua"
  require("yankdown.paste").start({ direction = "before" }, { notify = false })
  t.eq(_G.__native_direction, "before")
  _G.__native_direction = nil
  package.loaded["yankdown.native"] = nil
end)
