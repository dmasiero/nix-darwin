return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  opts = function(_, opts)
    -- Remove the time from lualine_z section
    opts.sections.lualine_z = {}
  end,
}