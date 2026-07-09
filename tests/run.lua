vim.opt.runtimepath:prepend(vim.fn.getcwd())
package.path = vim.fn.getcwd() .. "/tests/?.lua;" .. package.path

require("test_init")
require("test_paste")
require("test_clipboard")
require("tests.minitest").run()
