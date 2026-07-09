local M = {}

local function executable(name)
  return vim.fn.executable(name) == 1
end

function M.provider()
  if vim.fn.has("macunix") == 1 then
    if executable("osascript") then
      return {
        name = "macos",
        command = {
          "osascript",
          "-e",
          'the clipboard as «class HTML»',
        },
      }
    end
    return nil, "missing:osascript"
  end

  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    return nil, "unsupported"
  end

  if vim.env.WAYLAND_DISPLAY and executable("wl-paste") then
    return {
      name = "wayland",
      command = { "wl-paste", "-t", "text/html" },
    }
  end

  if vim.env.DISPLAY and executable("xclip") then
    return {
      name = "x11",
      command = { "xclip", "-selection", "clipboard", "-t", "text/html", "-o" },
    }
  end

  if vim.env.WAYLAND_DISPLAY then
    return nil, "missing:wl-paste"
  end

  if vim.env.DISPLAY then
    return nil, "missing:xclip"
  end

  return nil, "unsupported"
end

return M
