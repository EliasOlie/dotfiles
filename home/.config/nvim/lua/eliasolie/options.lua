-- Opções do editor
local o = vim.opt

o.number = true
o.relativenumber = true
o.cursorline = true
o.signcolumn = "yes"
o.scrolloff = 8
o.sidescrolloff = 8
o.wrap = false
o.linebreak = true
o.colorcolumn = ""
o.termguicolors = true
o.showmode = false                 -- o modo aparece na statusline
o.laststatus = 3                   -- uma statusline só, embaixo
o.cmdheight = 1
o.pumheight = 12
o.winborder = "single"             -- bordas retas, como os cards do desktop
o.fillchars = { eob = " ", vert = "│", fold = " " }
o.list = true
o.listchars = { tab = "→ ", trail = "·", nbsp = "␣" }

o.tabstop = 2
o.shiftwidth = 2
o.expandtab = true
o.smartindent = true

o.ignorecase = true
o.smartcase = true
o.inccommand = "split"

o.splitright = true
o.splitbelow = true
o.mouse = "a"
o.clipboard = "unnamedplus"        -- copia/cola com o resto do sistema (wl-clipboard)
o.undofile = true
o.swapfile = false
o.updatetime = 250
o.timeoutlen = 400
o.confirm = true                   -- pergunta antes de fechar com alteração
o.title = true
o.titlestring = "%t — nvim"

-- Go usa tab de verdade
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "go", "make" },
  callback = function() vim.opt_local.expandtab = false; vim.opt_local.tabstop = 4; vim.opt_local.shiftwidth = 4 end,
})

-- Destaque rápido do que foi copiado
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank({ higroup = "Visual", timeout = 160 }) end,
})

-- Volta para a última posição ao reabrir um arquivo
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Diagnósticos: texto ao lado só na linha atual; sinais discretos
vim.diagnostic.config({
  severity_sort = true,
  underline = true,
  update_in_insert = false,
  virtual_text = { current_line = true, spacing = 2, prefix = "■" },
  float = { border = "single", source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "■",
      [vim.diagnostic.severity.WARN] = "▲",
      [vim.diagnostic.severity.INFO] = "●",
      [vim.diagnostic.severity.HINT] = "·",
    },
  },
})
