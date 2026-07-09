local t = require("tests.minitest")

t.test("missing pandoc returns missing-pandoc", function()
  t.reset("yankdown.convert")
  local old_executable = vim.fn.executable
  vim.fn.executable = function(name) return name == "pandoc" and 0 or old_executable(name) end
  local markdown, err
  require("yankdown.convert").html_to_markdown("<p>Hello</p>", function(result, reason)
    markdown, err = result, reason
  end)
  vim.fn.executable = old_executable
  t.eq(markdown, nil)
  t.eq(err, "missing-pandoc")
end)

t.test("pandoc converts html and strips carriage returns", function()
  t.reset("yankdown.convert")
  local old_executable, old_system, old_schedule = vim.fn.executable, vim.system, vim.schedule
  vim.fn.executable = function(name) return name == "pandoc" and 1 or old_executable(name) end
  vim.schedule = function(fn) fn() end
  vim.system = function(cmd, opts, on_exit)
    t.eq(cmd[1], "pandoc")
    t.eq(opts.stdin, "<p>Hello</p>")
    on_exit({ code = 0, stdout = "Hello\r\n", stderr = "" })
    return {}
  end
  local markdown, err
  require("yankdown.convert").html_to_markdown("<p>Hello</p>", function(result, reason)
    markdown, err = result, reason
  end)
  vim.fn.executable = old_executable
  vim.system = old_system
  vim.schedule = old_schedule
  t.eq(markdown, "Hello\n")
  t.eq(err, nil)
end)
