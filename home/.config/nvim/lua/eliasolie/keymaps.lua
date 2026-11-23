-- Atalhos. Aperte Espaço e espere: o menu mostra todos, em português.
-- Convenções de editor comum onde existem (Ctrl+S, Ctrl+P, F2, Tab entre
-- arquivos) e grupos por assunto no Espaço: buscar, código, git, alternar.
local map = function(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { desc = desc, silent = true }) end
local fzf = function(cmd, opts) return function() require("fzf-lua")[cmd](opts or {}) end end

-- ---------------------------------------------------------------- básico
map({ "n", "i", "v" }, "<C-s>", "<Cmd>write<CR><Esc>", "salvar")
map("n", "<leader>w", "<Cmd>write<CR>", "salvar")
map("n", "<leader>q", function()                                -- fecha o arquivo, não a janela
  local cur = vim.api.nvim_get_current_buf()
  vim.cmd("bnext"); if vim.api.nvim_get_current_buf() == cur then vim.cmd("enew") end
  pcall(vim.api.nvim_buf_delete, cur, {})
end, "fechar arquivo")
map("n", "<leader>Q", "<Cmd>confirm qall<CR>", "sair do nvim")
map("n", "<Esc>", "<Cmd>nohlsearch<CR>", "limpar busca")
vim.keymap.set("n", "<C-/>", "gcc", { remap = true, desc = "comentar linha" })
vim.keymap.set("v", "<C-/>", "gc", { remap = true, desc = "comentar seleção" })
map("v", "<", "<gv", "recuar"); map("v", ">", ">gv", "avançar")
map("n", "<A-j>", "<Cmd>move .+1<CR>==", "descer linha"); map("n", "<A-k>", "<Cmd>move .-2<CR>==", "subir linha")
map("v", "<A-j>", ":move '>+1<CR>gv=gv", "descer seleção"); map("v", "<A-k>", ":move '<-2<CR>gv=gv", "subir seleção")

-- janelas (inclui a árvore): Ctrl + h/j/k/l
map("n", "<C-h>", "<C-w>h", "janela à esquerda"); map("n", "<C-l>", "<C-w>l", "janela à direita")
map("n", "<C-j>", "<C-w>j", "janela abaixo");     map("n", "<C-k>", "<C-w>k", "janela acima")
map("n", "<leader>|", "<Cmd>vsplit<CR>", "dividir ao lado"); map("n", "<leader>-", "<Cmd>split<CR>", "dividir embaixo")

-- arquivos abertos (abas no topo): Tab / Shift+Tab, como no navegador
map("n", "<Tab>", "<Cmd>bnext<CR>", "próximo arquivo aberto")
map("n", "<S-Tab>", "<Cmd>bprevious<CR>", "arquivo aberto anterior")
map("n", "<leader>bb", fzf("buffers"), "listar abertos")
map("n", "<leader>bo", function()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if b ~= vim.api.nvim_get_current_buf() and vim.bo[b].buflisted and not vim.bo[b].modified then pcall(vim.api.nvim_buf_delete, b, {}) end
  end
end, "fechar os outros")

-- ---------------------------------------------------------------- árvore (direita)
map("n", "<leader>e", "<Cmd>NvimTreeToggle<CR>", "árvore de arquivos")
map("n", "<leader>E", "<Cmd>NvimTreeFindFile!<CR>", "mostrar arquivo na árvore")

-- ---------------------------------------------------------------- buscar
map("n", "<C-p>", fzf("files"), "buscar arquivo")
map("n", "<leader><space>", fzf("files"), "buscar arquivo")
map("n", "<leader>/", fzf("live_grep"), "buscar texto no projeto")
map("n", "<leader>ff", fzf("files"), "arquivos")
map("n", "<leader>fg", fzf("live_grep"), "texto no projeto")
map({ "n", "v" }, "<leader>fw", fzf("grep_cword"), "palavra sob o cursor")
map("n", "<leader>fr", fzf("oldfiles"), "recentes")
map("n", "<leader>fb", fzf("buffers"), "abertos")
map("n", "<leader>fl", fzf("blines"), "linhas deste arquivo")
map("n", "<leader>fs", fzf("lsp_document_symbols"), "funções/símbolos do arquivo")
map("n", "<leader>fS", fzf("lsp_live_workspace_symbols"), "símbolos do projeto")
map("n", "<leader>fh", fzf("helptags"), "ajuda do nvim")
map("n", "<leader>fk", fzf("keymaps"), "atalhos")
map("n", "<leader>fc", fzf("commands"), "comandos")
map("n", "<leader>f.", fzf("resume"), "retomar última busca")

-- ---------------------------------------------------------------- código (quando há language server)
-- os atalhos padrão do 0.11+ começados em "gr" saem para "gr" ficar livre (referências)
for _, k in ipairs({ "grr", "gra", "grn", "gri", "grt" }) do pcall(vim.keymap.del, "n", k) end
pcall(vim.keymap.del, "x", "gra")
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local b = function(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc }) end
    b("n", "gd", fzf("lsp_definitions", { jump1 = true }), "ir para definição")
    b("n", "gD", vim.lsp.buf.declaration, "ir para declaração")
    b("n", "gr", fzf("lsp_references", { ignore_current_line = true }), "referências (quem usa)")
    b("n", "gI", fzf("lsp_implementations"), "implementações")
    b("n", "gy", fzf("lsp_typedefs"), "definição do tipo")
    b("n", "K", function() vim.lsp.buf.hover({ border = "single" }) end, "documentação")
    b("i", "<C-k>", function() vim.lsp.buf.signature_help({ border = "single" }) end, "assinatura da função")
    b("n", "<F2>", vim.lsp.buf.rename, "renomear")
    b("n", "<leader>cr", vim.lsp.buf.rename, "renomear")
    b({ "n", "v" }, "<leader>ca", fzf("lsp_code_actions"), "ações de código (corrigir, importar…)")
    b("n", "<leader>cd", function() vim.diagnostic.open_float() end, "problema desta linha")
    b("n", "<leader>ci", function()
      vim.lsp.buf.code_action({ apply = true, context = { only = { "source.organizeImports" }, diagnostics = {} } })
    end, "organizar imports")
  end,
})
map({ "n", "v" }, "<leader>cf", function() require("conform").format({ lsp_format = "fallback" }) end, "formatar")
map("n", "<leader>cm", "<Cmd>Mason<CR>", "language servers (Mason)")
map("n", "<leader>cl", "<Cmd>checkhealth vim.lsp<CR>", "status dos language servers")

-- ---------------------------------------------------------------- problemas
map("n", "<leader>xx", fzf("diagnostics_document"), "problemas do arquivo")
map("n", "<leader>xX", fzf("diagnostics_workspace"), "problemas do projeto")
map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "próximo problema")
map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "problema anterior")

-- ---------------------------------------------------------------- git
local gs = function(f, ...) local a = { ... } return function() require("gitsigns")[f](unpack(a)) end end
map("n", "]h", gs("nav_hunk", "next"), "próxima mudança (git)")
map("n", "[h", gs("nav_hunk", "prev"), "mudança anterior (git)")
map("n", "<leader>gp", gs("preview_hunk"), "ver mudança")
map("n", "<leader>gs", gs("stage_hunk"), "adicionar mudança (stage)")
map("n", "<leader>gr", gs("reset_hunk"), "desfazer mudança")
map("n", "<leader>gb", gs("blame_line", { full = true }), "quem mexeu nesta linha")
map("n", "<leader>gB", gs("toggle_current_line_blame"), "autor ao lado da linha (liga/desliga)")
map("n", "<leader>gd", gs("diffthis"), "comparar com o último commit")
map("n", "<leader>gg", fzf("git_status"), "arquivos alterados")
map("n", "<leader>gc", fzf("git_commits"), "commits")
map("n", "<leader>gC", fzf("git_bcommits"), "commits deste arquivo")

-- ---------------------------------------------------------------- alternar
map("n", "<leader>tf", function()
  vim.g.autoformat = vim.g.autoformat == false
  vim.notify("Formatar ao salvar: " .. (vim.g.autoformat and "ligado" or "desligado"))
end, "formatar ao salvar")
map("n", "<leader>th", function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled()) end, "dicas de tipo no código")
map("n", "<leader>tw", "<Cmd>set wrap!<CR>", "quebra de linha")
map("n", "<leader>tn", "<Cmd>set relativenumber!<CR>", "número relativo")
map("n", "<leader>tt", function() vim.cmd("botright 14split | terminal"); vim.cmd("startinsert") end, "terminal embaixo")
map("t", "<Esc><Esc>", "<C-\\><C-n>", "sair do modo terminal")
