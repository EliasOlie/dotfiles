-- Language servers: o Mason instala, o Neovim liga sozinho (vim.lsp.enable)
--   :Mason   tela para ver/instalar/atualizar servidores e formatadores
require("mason").setup({ ui = { border = "single", icons = { package_installed = "■", package_pending = "▸", package_uninstalled = "·" } } })

local servers = {
  "vtsls",          -- TypeScript / JavaScript / React
  "biome",          -- lint do Biome (projetos com biome.json)
  "tailwindcss",
  "gopls",          -- Go
  "lua_ls",
  "basedpyright",   -- Python
  "bashls",
  "jsonls", "cssls", "html", "yamlls",
}
require("mason-lspconfig").setup({ ensure_installed = servers, automatic_enable = true })

-- Instala o que faltar: servidores (nome do lspconfig -> pacote do Mason) e
-- formatadores usados no salvar (conform.nvim)
local tools = { "prettierd", "stylua", "goimports", "shfmt", "ruff" }
local to_pkg = require("mason-lspconfig").get_mappings().lspconfig_to_package
for _, s in ipairs(servers) do tools[#tools + 1] = to_pkg[s] or s end
local registry = require("mason-registry")
registry.refresh(function()
  for _, name in ipairs(tools) do
    local ok, pkg = pcall(registry.get_package, name)
    if ok and not pkg:is_installed() and not pkg:is_installing() then pkg:install() end
  end
end)

-- Ajustes por servidor
vim.lsp.config("lua_ls", { settings = { Lua = {
  runtime = { version = "LuaJIT" },
  workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
  diagnostics = { globals = { "vim", "hl" } },   -- "hl" = API do Hyprland (configs .lua)
} } })
vim.lsp.config("vtsls", { settings = { typescript = { inlayHints = { parameterNames = { enabled = "literals" } } } } })

-- QML (Quickshell): servidor do próprio Qt, já instalado no sistema
if vim.fn.executable("/usr/lib/qt6/bin/qmlls") == 1 then
  vim.lsp.config("qmlls", { cmd = { "/usr/lib/qt6/bin/qmlls" } })
  vim.lsp.enable("qmlls")
end

-- Autocompletar do blink alimentando todos os servidores
vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
