#!/bin/bash

# ====================================================================
# Neovim Configuration Installer for macOS
# Ported from m-vim
# ====================================================================

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Neovim Configuration Installer${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Check if Neovim is installed
if ! command -v nvim &> /dev/null; then
    echo -e "${RED}Error: Neovim is not installed${NC}"
    echo "Please install Neovim first:"
    echo "  brew install neovim"
    exit 1
fi

NVIM_VERSION=$(nvim --version | head -n1)
echo -e "${GREEN}Found: ${NVIM_VERSION}${NC}"
echo ""

# Set up directories
NVIM_CONFIG_DIR="${HOME}/.config/nvim"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE_LUA="${NVIM_CONFIG_DIR}/lua/config/private.lua"

# Create config directory if it doesn't exist
if [ ! -d "$NVIM_CONFIG_DIR" ]; then
    mkdir -p "$NVIM_CONFIG_DIR"
    echo -e "${YELLOW}Created Neovim config directory...${NC}"
fi

# Create symlinks for all files/folders (except private.lua)
echo -e "${YELLOW}Setting up symlinks...${NC}"

for item in "$SCRIPT_DIR"/*; do
    item_name=$(basename "$item")
    
    # Skip hidden files and directories
    if [[ "$item_name" == .* ]]; then
        continue
    fi
    
    # Skip private.lua (we handle it separately)
    if [ "$item_name" = "private.lua" ]; then
        continue
    fi
    
    target="${NVIM_CONFIG_DIR}/${item_name}"
    
    # Remove existing symlink/file if it points to the old location
    if [ -L "$target" ]; then
        rm "$target"
        echo -e "${GREEN}✓ Updated symlink: ${item_name}${NC}"
    elif [ ! -e "$target" ]; then
        echo -e "${YELLOW}Linking ${item_name}...${NC}"
    else
        # Don't overwrite existing files/directories
        echo -e "${YELLOW}Skipping ${item_name} (already exists)${NC}"
        continue
    fi
    
    ln -s "$item" "$target"
done

echo -e "${GREEN}Symlinks created${NC}"
echo ""

# Create private.lua only if it doesn't exist
if [ ! -f "$PRIVATE_LUA" ]; then
    echo -e "${YELLOW}Creating private.lua template...${NC}"
    mkdir -p "$(dirname "$PRIVATE_LUA")"
    
    cat > "$PRIVATE_LUA" << 'EOF'
-- ====================================================================
-- Private Customizations & Optional Plugins
-- ====================================================================
-- 
-- This file is for YOUR customizations!
-- 
-- 1. Add optional plugins by returning a table
-- 2. Add custom keymaps
-- 3. Add custom settings
-- 4. Add custom autocommands
--
-- The file will NOT be overwritten on updates.
-- ====================================================================

-- ====================================================================
-- OPTIONAL PLUGINS
-- ====================================================================
--
-- To add optional plugins, uncomment and modify the return statement below.
-- Then restart Neovim and plugins will auto-install.
--
-- Example: Enable Wakatime (time tracking)
-- ====================================================================

-- return {
--   -- Wakatime - Time tracking for coding
--   -- Get API key from: https://wakatime.com/settings/account
--   { 'wakatime/vim-wakatime' },
--
--   -- Other optional plugins you might like:
--   -- { 'tpope/vim-eunuch' },           -- Unix shell commands
--   -- { 'numToStr/Comment.nvim' },      -- Better commenting
--   -- { 'mbbill/undotree' },            -- Visual undo history
--   -- { 'folke/todo-comments.nvim' },   -- Highlight TODO comments
-- }

-- ====================================================================
-- CUSTOM KEYMAPS
-- ====================================================================
--
-- Example: Add custom keyboard shortcuts
-- ====================================================================

-- local map = vim.keymap.set
-- local opts = { noremap = true, silent = true }
--
-- -- Example: Map Ctrl+G to git status
-- map('n', '<C-g>', ':Gstatus<CR>', opts)
--
-- -- Example: Map leader + x to close buffer
-- map('n', '<leader>x', ':bdelete<CR>', opts)

-- ====================================================================
-- CUSTOM SETTINGS
-- ====================================================================
--
-- Example: Override default settings
-- ====================================================================

-- local opt = vim.opt
--
-- -- Example: Change tab width to 4 spaces
-- opt.tabstop = 4
-- opt.shiftwidth = 4
-- opt.softtabstop = 4
--
-- -- Example: Enable spell checking for markdown
-- -- vim.cmd('autocmd BufRead,BufNewFile *.md setlocal spell')

-- ====================================================================
-- CUSTOM AUTOCOMMANDS
-- ====================================================================
--
-- Example: Create custom auto-commands
-- ====================================================================

-- local augroup = vim.api.nvim_create_augroup
-- local autocmd = vim.api.nvim_create_autocmd
--
-- local my_group = augroup('MyCustomGroup', { clear = true })
--
-- -- Example: Auto-format on save for Python
-- autocmd('BufWritePre', {
--   group = my_group,
--   pattern = '*.py',
--   command = 'Autoformat',
-- })
--
-- -- Example: Set different tab width for YAML
-- autocmd('FileType', {
--   group = my_group,
--   pattern = 'yaml',
--   command = 'set ts=2 sw=2',
-- })

-- ====================================================================
-- WAKATIME CONFIGURATION (if enabled above)
-- ====================================================================
--
-- After enabling wakatime plugin, configure your API key:
-- ====================================================================

-- local g = vim.g
--
-- -- Option 1: Set API key directly (not recommended - expose your key)
-- -- g.wakatime_api_key = 'your-api-key-here'
--
-- -- Option 2: Use environment variable (RECOMMENDED)
-- -- Export in your shell: export WAKATIME_API_KEY='your-key'
-- -- The plugin will automatically read it
--
-- -- Optional settings:
-- g.wakatime_do_last_heartbeat = 1      -- Send heartbeat when editor closes
-- g.wakatime_cli_path = '/usr/local/bin/wakatime-cli'  -- Custom CLI path

-- ====================================================================
-- END OF CUSTOMIZATIONS
-- ====================================================================
EOF
    echo -e "${GREEN}✓ Created private.lua${NC}"
else
    echo -e "${GREEN}✓ private.lua already exists (not overwriting)${NC}"
fi

echo ""

# Snippets are already included in the package
echo -e "${GREEN}✓ Snippets included: all.snippets, python.snippets, js.snippets, c.snippets, cpp.snippets, go.snippets, php.snippets${NC}"

# Optional: Install optional dependencies
echo -e "${YELLOW}Installing optional dependencies...${NC}"
echo ""

# Check and install ripgrep (for better CtrlP performance)
if ! command -v rg &> /dev/null; then
    echo "ripgrep not found. Installing..."
    brew install ripgrep
else
    echo -e "${GREEN}✓ ripgrep already installed${NC}"
fi

# Check and install fzf (optional but useful)
if ! command -v fzf &> /dev/null; then
    echo "fzf not found. Installing..."
    brew install fzf
else
    echo -e "${GREEN}✓ fzf already installed${NC}"
fi

# Check and install ag (the_silver_searcher)
if ! command -v ag &> /dev/null; then
    echo "the_silver_searcher not found. Installing..."
    brew install the_silver_searcher
else
    echo -e "${GREEN}✓ the_silver_searcher already installed${NC}"
fi

# Check and install ctags
if ! command -v ctags &> /dev/null; then
    echo "ctags not found. Installing..."
    brew install universal-ctags
else
    echo -e "${GREEN}✓ ctags already installed${NC}"
fi

# Check for Python and pip
echo ""
echo -e "${YELLOW}Checking Python installation for YouCompleteMe...${NC}"

if ! command -v python3 &> /dev/null; then
    echo "Python 3 not found. Installing..."
    brew install python3
else
    echo -e "${GREEN}✓ Python 3 already installed${NC}"
fi

# Optional: Install build tools for YouCompleteMe
if ! command -v clang++ &> /dev/null; then
    echo -e "${YELLOW}Note: clang++ not found. Some YouCompleteMe features may not work.${NC}"
    echo "Install Xcode command line tools with: xcode-select --install"
else
    echo -e "${GREEN}✓ clang++ found${NC}"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Configuration location: ${NVIM_CONFIG_DIR}"
echo "Private customizations: ${PRIVATE_LUA}"
echo ""
echo "Next steps:"
echo "1. Open Neovim: nvim"
echo "2. Plugins will be automatically installed by lazy.nvim on first run"
echo ""
echo "Important notes:"
echo "- YouCompleteMe (YCM) requires: python3 -m pip install pynvim"
echo "- Some plugins may require additional setup"
echo "- Review the README.md for configuration details"
echo "- Edit private.lua to customize or add optional plugins"
echo ""
echo "Leader key is: comma (,)"
echo ""
echo "To uninstall, remove symlinks:"
echo "  rm -rf ${NVIM_CONFIG_DIR}"

