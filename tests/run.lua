vim.opt.runtimepath:prepend(vim.fn.getcwd())
package.path = vim.fn.getcwd() .. "/tests/?.lua;" .. package.path

require("test_init")
require("test_paste")
require("test_clipboard")
require("test_convert")
require("test_check")
require("tests.minitest").run()
