local M = {}

local function executable(name)
  return vim.fn.executable(name) == 1
end

local function windows_command(shell)
  local script = table.concat({
    "Add-Type -AssemblyName System.Windows.Forms;",
    "if ([System.Windows.Forms.Clipboard]::ContainsText([System.Windows.Forms.TextDataFormat]::Html)) {",
    "  $html = [System.Windows.Forms.Clipboard]::GetText([System.Windows.Forms.TextDataFormat]::Html);",
    "  $startMarker = '<!--StartFragment-->';",
    "  $endMarker = '<!--EndFragment-->';",
    "  $start = $html.IndexOf($startMarker);",
    "  $end = $html.IndexOf($endMarker);",
    "  if ($start -ge 0 -and $end -gt $start) {",
    "    $start = $start + $startMarker.Length;",
    "    $html.Substring($start, $end - $start);",
    "  } else {",
    "    $html;",
    "  }",
    "}",
  }, " ")

  return { shell, "-NoProfile", "-NonInteractive", "-Command", script }
end

function M.provider()
  if vim.fn.has("macunix") == 1 then
    if executable("osascript") then
      return {
        name = "macos",
        command = {
          "osascript",
          "-e",
          "the clipboard as «class HTML»",
        },
      }
    end
    return nil, "missing:osascript"
  end

  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    if executable("powershell") then
      return { name = "windows", command = windows_command("powershell") }
    end
    if executable("pwsh") then
      return { name = "windows", command = windows_command("pwsh") }
    end
    return nil, "missing:powershell"
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

function M.read_html(callback)
  local provider, err = M.provider()
  if not provider then
    callback(nil, err)
    return
  end

  vim.system(provider.command, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil, "clipboard-failed")
        return
      end

      local stdout = result.stdout or ""
      if stdout == "" then
        callback(nil, "no-html")
        return
      end

      callback(stdout, nil)
    end)
  end)
end

return M
