--- tests/integration/wayland_check.lua
---
--- Fallback integration check for Wayland when no compositor seat is available.
--- Tests that the clipboard provider is detected and pandoc conversion works.
--- These are the two components that can fail independently of the compositor.

vim.opt.runtimepath:prepend(vim.fn.getcwd())

-- 1. Provider detection
local provider = require("yankdown.clipboard").provider()
if not provider or provider.name ~= "wayland" then
  io.stderr:write("FAIL: Wayland provider not detected\n")
  vim.cmd("cquit")
end
print("PASS: Wayland provider: " .. provider.command[1])

-- 2. Pandoc conversion (same pipeline the paste path uses)
local out = vim.fn.system({ "pandoc", "-f", "html", "-t", "gfm-raw_html", "--wrap=none" }, "<p><b>Hello</b></p>")
if not out:match("%*%*Hello%*%*") then
  io.stderr:write("FAIL: pandoc conversion: " .. out .. "\n")
  vim.cmd("cquit")
end
print("PASS: pandoc HTML -> Markdown")
