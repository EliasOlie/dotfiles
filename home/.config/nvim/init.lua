-- Neovim eliasolie (0.12+) — mesma identidade visual do desktop.
--   Espaço  → menu de atalhos (which-key) com tudo descrito em português
--   Espaço e → árvore de arquivos (à direita)
-- Plugins pelo gerenciador nativo (vim.pack); versões travadas em nvim-pack-lock.json.

-- Node do nvm no PATH mesmo quando o nvim abre fora do zsh (rofi/atalho):
-- os language servers do TypeScript, Tailwind etc. precisam dele
do
  local bins = vim.fn.glob(vim.fn.expand("~/.nvm/versions/node/*/bin"), false, true)
  table.sort(bins)
  if #bins > 0 and vim.fn.executable("node") == 0 then
    vim.env.PATH = bins[#bins] .. ":" .. vim.env.PATH
  end
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("eliasolie.options")
require("eliasolie.plugins")
require("eliasolie.lsp")
require("eliasolie.keymaps")

vim.cmd.colorscheme("eliasolie")
