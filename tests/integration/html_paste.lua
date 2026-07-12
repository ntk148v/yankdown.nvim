--- tests/integration/html_paste.lua
---
--- Shared integration test for yankdown.nvim clipboard providers.
--- The CI job seeds the system clipboard with real HTML before this runs.
--- Checks that real HTML → yankdown → pandoc produces clean Markdown.

vim.opt.runtimepath:prepend(vim.fn.getcwd())

-- New markdown buffer
vim.api.nvim_command("enew!")
vim.bo.filetype = "markdown"
vim.fn.setline(1, "before")
vim.fn.cursor(1, 10) -- end of line 1

local yankdown = require("yankdown")
yankdown.setup({ notify = false, check = false })

-- Trigger async paste (direction="after" → after cursor)
yankdown.paste({ direction = "after" })

-- Poll every 100ms up to 10s: buffer should grow from 1 line to 2+ lines
-- after clipboard read + pandoc conversion + buffer insert.
local ok = vim.wait(10000, function()
  return vim.fn.line("$") > 1
end, 100)

if not ok then
  io.stderr:write("FAIL: paste did not complete within 10 s\n")
  vim.cmd("cquit")
end

-- Check the result
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
local content = table.concat(lines, "\n")
print("BUFFER:\n" .. content)

-- pandoc -t gfm-raw_html converts <p><b>Hello</b></p> to **Hello**
if content:find("%*%*Hello%*%*") or content:find("__Hello__") or content:find("%*Hello%*") then
  print("PASS: pasted bold Hello in Markdown from real clipboard HTML")
else
  io.stderr:write("FAIL: expected **Hello** in buffer, got: " .. content .. "\n")
  vim.cmd("cquit")
end
