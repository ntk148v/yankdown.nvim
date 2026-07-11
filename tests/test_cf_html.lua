local t = require("tests.minitest")

-- Build a CF_HTML payload and compute correct byte offsets.
-- Returns (payload, start_body) where start_body is the 0-based offset
-- where the body begins (past all header lines).
local function cf_html_payload(parts)
  -- parts is a table of header name->value and a `html` field for the body.
  -- Supported headers: start_html, end_html, start_fragment, end_fragment.
  local headers = {}
  local header_names = {
    "Version:0.9",
    "StartHTML",
    "EndHTML",
    "StartFragment",
    "EndFragment",
  }
  for _, name in ipairs(header_names) do
    if name == "Version:0.9" then
      table.insert(headers, "Version:0.9")
    elseif parts[name] ~= nil then
      table.insert(headers, ("%s:%010d"):format(name, parts[name]))
    end
  end
  local header_block = table.concat(headers, "\r\n") .. "\r\n"
  local payload = header_block .. (parts.html or "")
  -- Return the payload and the 0-based offset where body begins.
  return payload, #header_block
end

t.test("cf_html extracts StartFragment/EndFragment range", function()
  local parse = require("yankdown.cf_html").parse
  local body = "<!--StartFragment--><p>Hello</p><!--EndFragment-->"
  local start_body =
    #"Version:0.9\r\nStartHTML:0000000000\r\nEndHTML:0000000000\r\nStartFragment:0000000000\r\nEndFragment:0000000000\r\n"
  local payload, _ = cf_html_payload({
    StartHTML = start_body,
    EndHTML = start_body + #body,
    StartFragment = start_body,
    EndFragment = start_body + #body,
    html = body,
  })
  local out, err = parse(payload)
  t.eq(err, nil)
  t.ok(out:match("<p>Hello</p>"), "contains the HTML fragment")
  t.ok(not out:match("<!--StartFragment-->"), "StartFragment marker stripped")
  t.ok(not out:match("<!--EndFragment-->"), "EndFragment marker stripped")
end)

t.test("cf_html falls back to StartHTML/EndHTML when fragment missing", function()
  local parse = require("yankdown.cf_html").parse
  local body = "<html><body><p>Hello</p></body></html>"
  local start_body = #"Version:0.9\r\nStartHTML:0000000000\r\nEndHTML:0000000000\r\n"
  local payload, _ = cf_html_payload({
    StartHTML = start_body,
    EndHTML = start_body + #body,
    html = body,
  })
  local out, err = parse(payload)
  t.eq(err, nil)
  t.ok(out:match("<p>Hello</p>"), "contains the HTML content")
end)

t.test("cf_html accepts plain HTML payloads", function()
  local parse = require("yankdown.cf_html").parse
  local html, err = parse("<p>Hello</p>")
  t.eq(err, nil)
  t.eq(html, "<p>Hello</p>")
end)

t.test("cf_html returns no-html for empty payload", function()
  local parse = require("yankdown.cf_html").parse
  local html, err = parse("")
  t.eq(html, nil)
  t.eq(err, "no-html")
end)

t.test("cf_html returns no-html for nil payload", function()
  local parse = require("yankdown.cf_html").parse
  local html, err = parse(nil)
  t.eq(html, nil)
  t.eq(err, "no-html")
end)

t.test("cf_html returns no-html for non-HTML payload", function()
  local parse = require("yankdown.cf_html").parse
  local html, err = parse("This is plain text, not HTML")
  t.eq(html, nil)
  t.eq(err, "no-html")
end)

t.test("cf_html handles reversed StartFragment/EndFragment safely", function()
  local parse = require("yankdown.cf_html").parse
  -- StartFragment > EndFragment is invalid; no StartHTML/EndHTML either,
  -- and payload starts with "Version:" not "<", so no plain HTML fallback.
  local payload = table.concat({
    "Version:0.9\r\n",
    "StartFragment:0000000200\r\n",
    "EndFragment:0000000100\r\n",
    "<html><body><p>Hello</p></body></html>",
  })
  local html, err = parse(payload)
  t.eq(html, nil)
  t.eq(err, "no-html")
end)

t.test("cf_html strips leading whitespace for plain HTML detection", function()
  local parse = require("yankdown.cf_html").parse
  local html, err = parse("  \n  <p>Hello</p>")
  t.eq(err, nil)
  t.ok(html:match("<p>Hello</p>"), "detects HTML even with leading whitespace")
end)

t.test("cf_html returns trimmed fragment when markers are at edges", function()
  local parse = require("yankdown.cf_html").parse
  local body = "<!--StartFragment--><b>Hi</b><!--EndFragment-->"
  local start_body =
    #"Version:0.9\r\nStartHTML:0000000000\r\nEndHTML:0000000000\r\nStartFragment:0000000000\r\nEndFragment:0000000000\r\n"
  local payload, _ = cf_html_payload({
    StartHTML = start_body,
    EndHTML = start_body + #body,
    StartFragment = start_body,
    EndFragment = start_body + #body,
    html = body,
  })
  local out, err = parse(payload)
  t.eq(err, nil)
  t.eq(out, "<b>Hi</b>")
end)

t.test("cf_html handles missing body gracefully", function()
  local parse = require("yankdown.cf_html").parse
  local start_body =
    #"Version:0.9\r\nStartHTML:0000000000\r\nEndHTML:0000000000\r\nStartFragment:0000000000\r\nEndFragment:0000000000\r\n"
  local payload, _ = cf_html_payload({
    StartHTML = start_body,
    EndHTML = start_body,
    StartFragment = start_body,
    EndFragment = start_body,
    html = "",
  })
  local html, err = parse(payload)
  t.eq(html, nil)
  t.eq(err, "no-html")
end)
