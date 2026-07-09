local M = { tests = {} }

function M.test(name, fn)
  table.insert(M.tests, { name = name, fn = fn })
end

function M.eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "values differ") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual), 2)
  end
end

function M.ok(value, msg)
  if not value then
    error(msg or "expected truthy value", 2)
  end
end

function M.reset(module)
  package.loaded[module] = nil
end

function M.run()
  local failed = 0
  for _, t in ipairs(M.tests) do
    local ok, err = pcall(t.fn)
    if ok then
      print("PASS " .. t.name)
    else
      failed = failed + 1
      print("FAIL " .. t.name .. "\n" .. err)
    end
  end
  if failed > 0 then
    vim.cmd("cquit")
  end
end

return M
