local t = require("tests.minitest")

t.test("native paste feeds p or P", function()
  t.reset("yankdown.native")
  local calls = {}
  local old_feedkeys, old_replace = vim.api.nvim_feedkeys, vim.api.nvim_replace_termcodes
  vim.api.nvim_replace_termcodes = function(keys)
    return keys
  end
  vim.api.nvim_feedkeys = function(keys, mode)
    table.insert(calls, { keys = keys, mode = mode })
  end

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
    paste = function(direction)
      _G.__native_direction = direction
    end,
  }
  vim.bo.filetype = "lua"
  require("yankdown.paste").start({ direction = "before" }, { notify = false })
  t.eq(_G.__native_direction, "before")
  _G.__native_direction = nil
  package.loaded["yankdown.native"] = nil
end)

t.test("insert normal after uses characterwise put after cursor", function()
  t.reset("yankdown.paste")
  local old_mode, old_put = vim.api.nvim_get_mode, vim.api.nvim_put
  local call
  vim.api.nvim_get_mode = function()
    return { mode = "n" }
  end
  vim.api.nvim_put = function(lines, type, after, follow)
    call = { lines = lines, type = type, after = after, follow = follow }
  end
  require("yankdown.paste").insert("# Hello\nWorld\n", "after")
  vim.api.nvim_get_mode, vim.api.nvim_put = old_mode, old_put
  t.eq(call.lines[1], "# Hello")
  t.eq(call.lines[2], "World")
  t.eq(call.type, "c")
  t.eq(call.after, true)
end)

t.test("insert normal before uses characterwise put before cursor", function()
  t.reset("yankdown.paste")
  local old_mode, old_put = vim.api.nvim_get_mode, vim.api.nvim_put
  local call
  vim.api.nvim_get_mode = function()
    return { mode = "n" }
  end
  vim.api.nvim_put = function(lines, type, after, follow)
    call = { lines = lines, type = type, after = after, follow = follow }
  end
  require("yankdown.paste").insert("Hello", "before")
  vim.api.nvim_get_mode, vim.api.nvim_put = old_mode, old_put
  t.eq(call.type, "c")
  t.eq(call.after, false)
end)

t.test("insert insert-mode uses characterwise put", function()
  t.reset("yankdown.paste")
  local old_mode, old_put = vim.api.nvim_get_mode, vim.api.nvim_put
  local call
  vim.api.nvim_get_mode = function()
    return { mode = "i" }
  end
  vim.api.nvim_put = function(lines, type, after, follow)
    call = { lines = lines, type = type, after = after, follow = follow }
  end
  require("yankdown.paste").insert("Hello", "after")
  vim.api.nvim_get_mode, vim.api.nvim_put = old_mode, old_put
  t.eq(call.type, "c")
  t.eq(call.after, true)
end)

t.test("markdown buffer inserts converted html", function()
  t.reset("yankdown.paste")
  vim.bo.filetype = "markdown"
  local old_schedule = vim.schedule
  vim.schedule = function(fn)
    fn()
  end
  package.loaded["yankdown.clipboard"] = {
    read_html = function(cb)
      cb("<p>Hello</p>", nil)
    end,
  }
  package.loaded["yankdown.convert"] = {
    html_to_markdown = function(html, cb)
      t.eq(html, "<p>Hello</p>")
      cb("Hello", nil)
    end,
  }
  package.loaded["yankdown.native"] = {
    paste = function()
      error("native paste should not run")
    end,
  }
  local paste = require("yankdown.paste")
  local old_insert = paste.insert
  local inserted
  paste.insert = function(markdown, direction)
    inserted = { markdown = markdown, direction = direction }
  end
  paste.start({ direction = "after" }, { notify = false })
  paste.insert = old_insert
  vim.schedule = old_schedule
  package.loaded["yankdown.clipboard"] = nil
  package.loaded["yankdown.convert"] = nil
  package.loaded["yankdown.native"] = nil
  t.eq(inserted.markdown, "Hello")
  t.eq(inserted.direction, "after")
end)

t.test("no html falls back silently", function()
  t.reset("yankdown.paste")
  vim.bo.filetype = "markdown"
  local old_schedule = vim.schedule
  vim.schedule = function(fn)
    fn()
  end
  package.loaded["yankdown.clipboard"] = {
    read_html = function(cb)
      cb(nil, "no-html")
    end,
  }
  package.loaded["yankdown.native"] = {
    paste = function(direction)
      _G.__fallback_direction = direction
    end,
  }
  require("yankdown.paste").start({ direction = "before" }, { notify = true })
  vim.schedule = old_schedule
  package.loaded["yankdown.clipboard"] = nil
  package.loaded["yankdown.native"] = nil
  t.eq(_G.__fallback_direction, "before")
  _G.__fallback_direction = nil
end)

t.test("missing pandoc warns once", function()
  t.reset("yankdown.paste")
  vim.bo.filetype = "markdown"
  local notices = 0
  local old_notify = vim.notify
  local old_schedule = vim.schedule
  vim.schedule = function(fn)
    fn()
  end
  vim.notify = function(msg, level)
    notices = notices + 1
    t.ok(msg:match("pandoc"), "notification mentions pandoc")
  end
  package.loaded["yankdown.clipboard"] = {
    read_html = function(cb)
      cb("<p>Hello</p>", nil)
    end,
  }
  package.loaded["yankdown.convert"] = {
    html_to_markdown = function(html, cb)
      cb(nil, "missing-pandoc")
    end,
  }
  package.loaded["yankdown.native"] = {
    paste = function() end,
  }
  local paste = require("yankdown.paste")
  paste.start({ direction = "after" }, { notify = true })
  paste.start({ direction = "after" }, { notify = true })
  vim.notify = old_notify
  vim.schedule = old_schedule
  package.loaded["yankdown.clipboard"] = nil
  package.loaded["yankdown.convert"] = nil
  package.loaded["yankdown.native"] = nil
  t.eq(notices, 1)
end)

t.test("notify false suppresses fallback warnings", function()
  t.reset("yankdown.paste")
  vim.bo.filetype = "markdown"
  local notices = 0
  local old_notify = vim.notify
  vim.notify = function()
    notices = notices + 1
  end
  package.loaded["yankdown.clipboard"] = {
    read_html = function(cb)
      cb("<p>Hello</p>", nil)
    end,
  }
  package.loaded["yankdown.convert"] = {
    html_to_markdown = function(_, cb)
      cb(nil, "missing-pandoc")
    end,
  }
  package.loaded["yankdown.native"] = {
    paste = function() end,
  }

  require("yankdown.paste").start({ direction = "after" }, { notify = false })

  vim.notify = old_notify
  package.loaded["yankdown.clipboard"] = nil
  package.loaded["yankdown.convert"] = nil
  package.loaded["yankdown.native"] = nil
  t.eq(notices, 0)
end)
