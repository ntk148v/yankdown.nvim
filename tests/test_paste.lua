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

t.test("insert normal after uses linewise put after cursor", function()
  t.reset("yankdown.paste")
  local old_mode, old_put = vim.api.nvim_get_mode, vim.api.nvim_put
  local call
  vim.api.nvim_get_mode = function() return { mode = "n" } end
  vim.api.nvim_put = function(lines, type, after, follow)
    call = { lines = lines, type = type, after = after, follow = follow }
  end
  require("yankdown.paste").insert("# Hello\nWorld\n", "after")
  vim.api.nvim_get_mode, vim.api.nvim_put = old_mode, old_put
  t.eq(call.lines[1], "# Hello")
  t.eq(call.lines[2], "World")
  t.eq(call.type, "l")
  t.eq(call.after, true)
end)

t.test("insert normal before uses linewise put before cursor", function()
  t.reset("yankdown.paste")
  local old_mode, old_put = vim.api.nvim_get_mode, vim.api.nvim_put
  local call
  vim.api.nvim_get_mode = function() return { mode = "n" } end
  vim.api.nvim_put = function(lines, type, after, follow)
    call = { lines = lines, type = type, after = after, follow = follow }
  end
  require("yankdown.paste").insert("Hello", "before")
  vim.api.nvim_get_mode, vim.api.nvim_put = old_mode, old_put
  t.eq(call.after, false)
end)

t.test("insert insert-mode uses characterwise put", function()
  t.reset("yankdown.paste")
  local old_mode, old_put = vim.api.nvim_get_mode, vim.api.nvim_put
  local call
  vim.api.nvim_get_mode = function() return { mode = "i" } end
  vim.api.nvim_put = function(lines, type, after, follow)
    call = { lines = lines, type = type, after = after, follow = follow }
  end
  require("yankdown.paste").insert("Hello", "after")
  vim.api.nvim_get_mode, vim.api.nvim_put = old_mode, old_put
  t.eq(call.type, "c")
  t.eq(call.after, true)
end)
