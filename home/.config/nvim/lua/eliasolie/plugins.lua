-- Plugins (gerenciador nativo do Neovim 0.12: vim.pack)
--   :lua vim.pack.update()   atualiza (mostra o que muda antes de aplicar)
local gh = function(repo) return "https://github.com/" .. repo end

vim.pack.add({
  gh("nvim-tree/nvim-web-devicons"),
  gh("nvim-tree/nvim-tree.lua"),            -- árvore de arquivos (à direita)
  gh("ibhagwan/fzf-lua"),                   -- buscar arquivos / texto / símbolos
  gh("nvim-lualine/lualine.nvim"),          -- barra de status e de arquivos abertos
  gh("lewis6991/gitsigns.nvim"),            -- git na margem
  gh("folke/which-key.nvim"),               -- menu de atalhos ao apertar Espaço
  gh("nvim-mini/mini.nvim"),                -- pares automáticos, objetos de texto, surround
  { src = gh("nvim-treesitter/nvim-treesitter"), version = "main" },
  gh("neovim/nvim-lspconfig"),
  gh("mason-org/mason.nvim"),               -- instala language servers e formatadores
  gh("mason-org/mason-lspconfig.nvim"),
  { src = gh("saghen/blink.cmp"), version = vim.version.range("1.*") },  -- autocompletar
  gh("stevearc/conform.nvim"),              -- formatar ao salvar
}, { confirm = false })

local c = {
  void = "#050505", graphite = "#161614", line = "#2A2A27", static = "#8A8A84",
  bone = "#EDEDE8", signal = "#C8F031", alert = "#FF5A4E", warn = "#F2C94C", blue = "#7AA7FF",
}

-- ---------------------------------------------------------------- árvore de arquivos (direita)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
require("nvim-tree").setup({
  view = { side = "right", width = 34, signcolumn = "no" },
  renderer = {
    root_folder_label = function(path) return "  " .. vim.fn.fnamemodify(path, ":t"):upper() end,
    indent_markers = { enable = true },
    highlight_git = "name",
    icons = { git_placement = "after", glyphs = { git = {
      unstaged = "●", staged = "✓", unmerged = "", renamed = "➜", untracked = "+", deleted = "✗", ignored = "◌",
    } } },
  },
  update_focused_file = { enable = true },          -- acompanha o arquivo aberto
  filters = { dotfiles = false, custom = { "^.git$", "node_modules" } },
  git = { ignore = false },
  actions = { open_file = { window_picker = { enable = false } } },
  on_attach = function(bufnr)
    local api = require("nvim-tree.api")
    api.config.mappings.default_on_attach(bufnr)
    local map = function(k, f, d) vim.keymap.set("n", k, f, { buffer = bufnr, desc = d }) end
    map("l", api.node.open.edit, "abrir")
    map("h", api.node.navigate.parent_close, "fechar pasta")
    map("?", api.tree.toggle_help, "ajuda da árvore")
  end,
})

-- ---------------------------------------------------------------- busca (fzf)
require("fzf-lua").setup({
  "default-title",
  winopts = { border = "single", preview = { border = "single", layout = "flex" }, backdrop = 100 },
  fzf_colors = true,
  files = { cwd_prompt = false, prompt = "arquivos ▸ " },
  grep = { prompt = "texto ▸ " },
})

-- ---------------------------------------------------------------- statusline (estilo waybar)
local theme = {
  normal = { a = { fg = c.void, bg = c.signal, gui = "bold" }, b = { fg = c.bone, bg = c.graphite }, c = { fg = c.static, bg = c.void } },
  insert = { a = { fg = c.void, bg = c.bone, gui = "bold" } },
  visual = { a = { fg = c.void, bg = c.warn, gui = "bold" } },
  replace = { a = { fg = c.void, bg = c.alert, gui = "bold" } },
  command = { a = { fg = c.signal, bg = c.graphite, gui = "bold" } },
  terminal = { a = { fg = c.void, bg = c.blue, gui = "bold" } },
  inactive = { a = { fg = c.static, bg = c.void }, b = { fg = c.static, bg = c.void }, c = { fg = c.static, bg = c.void } },
}
local modes = { NORMAL = "NORMAL", INSERT = "INSERIR", VISUAL = "VISUAL", ["V-LINE"] = "V-LINHA",
  ["V-BLOCK"] = "V-BLOCO", REPLACE = "SUBSTITUIR", COMMAND = "COMANDO", TERMINAL = "TERMINAL" }
local function lsp_names()
  local names = {}
  for _, cl in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do names[#names + 1] = cl.name end
  return #names > 0 and ("LSP " .. table.concat(names, " · ")) or ""
end
require("lualine").setup({
  options = {
    theme = theme, globalstatus = true,
    section_separators = "", component_separators = { left = "│", right = "│" },
    disabled_filetypes = { statusline = {}, tabline = { "NvimTree" } },
  },
  sections = {
    lualine_a = { { "mode", fmt = function(m) return modes[m] or m end } },
    lualine_b = { { "branch", icon = "" }, { "diff", diff_color = { added = { fg = c.signal }, modified = { fg = c.blue }, removed = { fg = c.alert } } } },
    lualine_c = { { "filename", path = 1, symbols = { modified = " ●", readonly = " ", unnamed = "sem nome" } } },
    lualine_x = {
      { "diagnostics", symbols = { error = "■ ", warn = "▲ ", info = "● ", hint = "· " } },
      { lsp_names, color = { fg = c.static } },
      { "filetype", colored = false },
    },
    lualine_y = { { "progress" } },
    lualine_z = { { "location" } },
  },
  -- arquivos abertos no topo, como os workspaces da waybar (ativo em lima)
  tabline = {
    lualine_a = { {
      "buffers", mode = 0, max_length = vim.o.columns,
      symbols = { modified = " ●", alternate_file = "", directory = "" },
      filetype_names = { NvimTree = "árvore", ["fzf"] = "busca", mason = "mason" },
      buffers_color = { active = { fg = c.void, bg = c.signal, gui = "bold" }, inactive = { fg = c.static, bg = c.void } },
    } },
  },
})

-- ---------------------------------------------------------------- git na margem
require("gitsigns").setup({
  signs = { add = { text = "▎" }, change = { text = "▎" }, delete = { text = "▁" }, topdelete = { text = "▔" }, changedelete = { text = "▎" } },
  current_line_blame_opts = { delay = 400 },
})

-- ---------------------------------------------------------------- mini: pares, objetos de texto, surround
require("mini.pairs").setup()
require("mini.ai").setup()
require("mini.surround").setup()   -- sa"  envolve em aspas · sd" tira · sr"' troca

-- ---------------------------------------------------------------- treesitter (cores e indentação)
local parsers = { "bash", "css", "diff", "dockerfile", "go", "gomod", "html", "javascript", "json",
  "lua", "markdown", "markdown_inline", "python", "qmljs", "query", "regex", "sql", "toml", "tsx",
  "typescript", "vim", "vimdoc", "yaml" }
pcall(function() require("nvim-treesitter").install(parsers) end)
vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev)
    if pcall(vim.treesitter.start, ev.buf) then
      vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

-- ---------------------------------------------------------------- autocompletar
require("blink.cmp").setup({
  keymap = { preset = "default", ["<CR>"] = { "accept", "fallback" }, ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
             ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" } },
  appearance = { nerd_font_variant = "mono" },
  completion = {
    menu = { border = "single", draw = { columns = { { "kind_icon" }, { "label", "label_description", gap = 1 } } } },
    documentation = { auto_show = true, auto_show_delay_ms = 300, window = { border = "single" } },
    list = { selection = { preselect = true, auto_insert = false } },
  },
  signature = { enabled = true, window = { border = "single" } },
  sources = { default = { "lsp", "path", "snippets", "buffer" } },
})

-- ---------------------------------------------------------------- formatar ao salvar
require("conform").setup({
  formatters_by_ft = {
    javascript = { "biome", "prettierd", stop_after_first = true },
    javascriptreact = { "biome", "prettierd", stop_after_first = true },
    typescript = { "biome", "prettierd", stop_after_first = true },
    typescriptreact = { "biome", "prettierd", stop_after_first = true },
    json = { "biome", "prettierd", stop_after_first = true },
    css = { "biome", "prettierd", stop_after_first = true },
    html = { "prettierd" }, markdown = { "prettierd" }, yaml = { "prettierd" },
    lua = { "stylua" }, go = { "goimports", "gofmt" }, python = { "ruff_format" },
    sh = { "shfmt" }, bash = { "shfmt" },
  },
  -- Biome só onde o projeto usa (biome.json); senão cai no Prettier
  formatters = { biome = { require_cwd = true } },
  format_on_save = function(buf)
    if vim.g.autoformat == false or vim.b[buf].autoformat == false then return end
    return { timeout_ms = 1500, lsp_format = "fallback" }
  end,
})

-- ---------------------------------------------------------------- menu de atalhos
require("which-key").setup({
  preset = "helix",
  delay = 300,
  win = { border = "single", title = true, title_pos = "left" },
  icons = { mappings = false, separator = "→", group = "+ " },
  spec = {
    { "<leader>b", group = "arquivos abertos" },
    { "<leader>c", group = "código" },
    { "<leader>f", group = "buscar" },
    { "<leader>g", group = "git" },
    { "<leader>t", group = "alternar" },
    { "<leader>x", group = "problemas" },
  },
})
