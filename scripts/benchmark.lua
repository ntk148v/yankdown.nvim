vim.opt.runtimepath:prepend(vim.fn.getcwd())

local paste = require("yankdown.paste")
local clipboard = require("yankdown.clipboard")

local function bench(name, iterations, fn)
  collectgarbage("collect")
  local started = vim.loop.hrtime()
  for _ = 1, iterations do
    fn()
  end
  local elapsed_ms = (vim.loop.hrtime() - started) / 1000000
  print(("%s\t%.6f"):format(name, elapsed_ms / iterations))
end

print("benchmark\tms_per_op")

local markdown = table.concat({
  "# Heading",
  "",
  "- one",
  "- two",
  "- three",
  "",
  "A short paragraph with **bold** text.",
}, "\n")

local old_mode = vim.api.nvim_get_mode
local old_put = vim.api.nvim_put
vim.api.nvim_get_mode = function()
  return { mode = "n" }
end
vim.api.nvim_put = function() end

bench("paste_insert_normal", 10000, function()
  paste.insert(markdown, "after")
end)

vim.api.nvim_get_mode = old_mode
vim.api.nvim_put = old_put

local old_has = vim.fn.has
local old_executable = vim.fn.executable
local old_wayland = vim.env.WAYLAND_DISPLAY
local old_display = vim.env.DISPLAY

vim.fn.has = function()
  return 0
end
vim.fn.executable = function(name)
  return name == "wl-paste" and 1 or 0
end
vim.env.WAYLAND_DISPLAY = "wayland-0"
vim.env.DISPLAY = nil

bench("clipboard_provider_wayland", 10000, function()
  local provider, err = clipboard.provider()
  if err or not provider or provider.name ~= "wayland" then
    error("expected wayland provider")
  end
end)

vim.fn.has = old_has
vim.fn.executable = old_executable
vim.env.WAYLAND_DISPLAY = old_wayland
vim.env.DISPLAY = old_display
