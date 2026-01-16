-- ====================================================================
-- LSP Configuration
-- ====================================================================

-- Configure diagnostics to show virtual text (inline on code)
vim.diagnostic.config({
  virtual_text = {
    prefix = "",
    spacing = 4,
  },
  signs = false,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

local lspconfig = vim.lsp.config

local capabilities = vim.lsp.protocol.make_client_capabilities()
local cmp_ok, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
if cmp_ok then
  capabilities = cmp_lsp.default_capabilities(capabilities)
end

local function setup_if_executable(server, cmd, opts)
  if cmd and vim.fn.executable(cmd) == 0 then
    return
  end
  if not lspconfig[server] then
    return
  end
  opts = opts or {}
  opts.capabilities = capabilities
  lspconfig(server, opts)
  vim.lsp.enable(server)
end

setup_if_executable('ts_ls', 'typescript-language-server')
setup_if_executable('pyright', 'pyright-langserver')
setup_if_executable('gopls', 'gopls')
setup_if_executable('clangd', 'clangd')
setup_if_executable('bashls', 'bash-language-server')
setup_if_executable('jsonls', 'vscode-json-language-server')
setup_if_executable('yamlls', 'yaml-language-server')
setup_if_executable('lua_ls', 'lua-language-server', {
  settings = {
    Lua = {
      diagnostics = { globals = { 'vim' } },
      workspace = { checkThirdParty = false },
    },
  },
})
