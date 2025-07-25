-- Save & restore session status.
return {
  "folke/persistence.nvim",
  event = "BufReadPre",
  opts = {
    options = { "buffers", "curdir", "tabpages", "winsize" },
  },
  keys = {
    { "<leader>qs", function() require("persistence").load() end, desc = "Restore Session" },
    { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
    { "<leader>qd", function() require("persistence").stop() end, desc = "Disable Session Save" },
  },
}