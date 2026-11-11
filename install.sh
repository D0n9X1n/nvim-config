#!/bin/bash
# Install public Neovim runtime files; keep local extension files unmanaged.
set -euo pipefail

NO_DEPS=false
for arg in "$@"; do
    case "$arg" in
        --no-deps) NO_DEPS=true ;;
        -h|--help)
            printf 'Usage: %s [--no-deps]\nRequires Neovim 0.12+.\n' "$0"
            exit 0 ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; exit 1 ;;
    esac
done

# Gate before mkdir, backup, symlink replacement, or dependency installation.
if ! command -v nvim >/dev/null 2>&1; then
    printf 'Error: Neovim 0.12+ is required; install Neovim first.\n' >&2
    exit 1
fi
VERSION=$(nvim --version) || { printf 'Error: cannot query Neovim 0.12+ version.\n' >&2; exit 1; }
if [[ ! "$VERSION" =~ ^NVIM\ v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    printf 'Error: cannot verify Neovim version; Neovim 0.12+ is required.\n' >&2
    exit 1
fi
if (( 10#${BASH_REMATCH[1]} == 0 && 10#${BASH_REMATCH[2]} < 12 )); then
    printf 'Error: Neovim 0.12+ is required; found %s.\n' "${VERSION%%$'\n'*}" >&2
    exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
if [[ "$CONFIG_HOME" != /* ]]; then
    printf 'Error: XDG_CONFIG_HOME must be an absolute path.\n' >&2
    exit 1
fi
NVIM_CONFIG_DIR="$CONFIG_HOME/nvim"
if [[ -d "$NVIM_CONFIG_DIR" ]] && [[ $(cd -- "$NVIM_CONFIG_DIR" && pwd -P) == "$SCRIPT_DIR" ]]; then
    printf 'Checkout is already the Neovim configuration; no links or backups needed.\n'
    exit 0
fi

# Dependencies are optional, but preserve the existing auto-install behavior.
# Check brew only if a package is actually missing, before changing the config.
DEPENDENCIES=(rg fzf ag ctags python3)
PACKAGES=(ripgrep fzf the_silver_searcher universal-ctags python3)
if ! "$NO_DEPS"; then
    for command in "${DEPENDENCIES[@]}"; do
        if ! command -v "$command" >/dev/null 2>&1 && ! command -v brew >/dev/null 2>&1; then
            printf 'Error: %s is missing and brew is unavailable. Install Homebrew or use --no-deps.\n' "$command" >&2
            exit 1
        fi
    done
fi

# Dereference live links so backups survive changes to the old checkout/targets.
# Keep dangling links as links. A depth limit rejects cycles before replacement.
# All copying finishes before any existing configuration is modified.
shopt -s dotglob nullglob
snapshot() {
    local src=$1 dst=$2 depth=$3 child ancestor
    shift 3
    if (( depth > 64 )); then
        printf 'Error: config exceeds 64 directory levels: %s\n' "$src" >&2
        return 1
    fi
    if [[ -d "$src" ]]; then
        for ancestor in "$@"; do
            if [[ "$src" -ef "$ancestor" ]]; then
                printf 'Error: config contains a symlink cycle: %s\n' "$src" >&2
                return 1
            fi
        done
        mkdir -- "$dst" || return 1
        for child in "$src"/*; do
            snapshot "$child" "$dst/${child##*/}" "$((depth + 1))" "$@" "$src" || return 1
        done
    elif [[ -L "$src" && ! -e "$src" ]]; then
        cp -Pp -- "$src" "$dst"
    else
        cp -Lp -- "$src" "$dst"
    fi
}

RUNTIME=(init.lua UltiSnips lua/plugins lua/config/plugins)
for item in "$SCRIPT_DIR/lua/config"/*.lua; do
    case "${item##*/}" in
        private.lua|private_config.lua) continue ;;
    esac
    RUNTIME+=("lua/config/${item##*/}")
done
NEEDS_LINKS=false
for item in "${RUNTIME[@]}"; do
    target="$NVIM_CONFIG_DIR/$item"
    if [[ ! -L "$target" || $(readlink -- "$target") != "$SCRIPT_DIR/$item" ]]; then
        NEEDS_LINKS=true
    fi
done
for item in "$NVIM_CONFIG_DIR" "$NVIM_CONFIG_DIR/lua" "$NVIM_CONFIG_DIR/lua/config"; do
    if [[ -L "$item" || ! -d "$item" ]]; then
        NEEDS_LINKS=true
    fi
done

mkdir -p -- "$CONFIG_HOME"
BACKUP_DIR=''
if "$NEEDS_LINKS" && [[ -e "$NVIM_CONFIG_DIR" || -L "$NVIM_CONFIG_DIR" ]]; then
    BACKUP_DIR=$(mktemp -d "$CONFIG_HOME/nvim.backup.XXXXXX")
    snapshot "$NVIM_CONFIG_DIR" "$BACKUP_DIR/config" 0
    printf 'Backup created: %s/config\n' "$BACKUP_DIR"
fi

# Never traverse symlinked containers while modifying the installation. Restore
# their independent snapshot locally, including both private extension files.
local_directory() {
    local target=$1 saved=$2
    if [[ -L "$target" || ( -e "$target" && ! -d "$target" ) ]]; then
        rm -- "$target"
        if [[ -d "$saved" && ! -L "$saved" ]]; then
            cp -Rp -- "$saved" "$target"
        fi
    fi
    mkdir -p -- "$target"
}
local_directory "$NVIM_CONFIG_DIR" "$BACKUP_DIR/config"
local_directory "$NVIM_CONFIG_DIR/lua" "$BACKUP_DIR/config/lua"
local_directory "$NVIM_CONFIG_DIR/lua/config" "$BACKUP_DIR/config/lua/config"

link_item() {
    local src=$1 target=$2
    if [[ -L "$target" && $(readlink -- "$target") == "$src" ]]; then
        return
    fi
    # rm removes a leaf symlink itself, never its referenced file/directory.
    if [[ -e "$target" || -L "$target" ]]; then
        rm -rf -- "$target"
    fi
    ln -s -- "$src" "$target"
}

for item in "${RUNTIME[@]}"; do
    link_item "$SCRIPT_DIR/$item" "$NVIM_CONFIG_DIR/$item"
done

# A dangling private symlink is still user-owned; never write through it.
PRIVATE_LUA="$NVIM_CONFIG_DIR/lua/config/private.lua"
if [[ ! -e "$PRIVATE_LUA" && ! -L "$PRIVATE_LUA" ]]; then
    printf '%s\n' '-- Optional personal plugin specs. This file is never overwritten.' 'return {}' > "$PRIVATE_LUA"
fi

if ! "$NO_DEPS"; then
    for i in "${!DEPENDENCIES[@]}"; do
        if ! command -v "${DEPENDENCIES[$i]}" >/dev/null 2>&1; then
            brew install "${PACKAGES[$i]}"
        fi
    done
    if ! command -v clang++ >/dev/null 2>&1; then
        printf 'Note: clang++ not found. Install Xcode command line tools with: xcode-select --install\n'
    fi
fi

# Install the declared plugins, then remove clones the spec no longer names.
# lazy decides what is undeclared; prune-plugins.sh keeps any with local work.
# Declared means a plugin name or its resolved directory. A private.lua that
# fails to load, or a plugin spec error, writes no list, so nothing is removed.
if ! "$NO_DEPS" && command -v nvim >/dev/null 2>&1; then
    nvim --headless '+Lazy! install' +qa || printf 'Warning: Lazy install did not finish; open nvim to retry.\n' >&2
    PRUNE_DIR="$(mktemp -d)"
    trap 'rm -rf -- "$PRUNE_DIR"' EXIT
    export NVIM_PRUNE_DECLARED="$PRUNE_DIR/declared" NVIM_PRUNE_CANDIDATES="$PRUNE_DIR/candidates" NVIM_PRUNE_ROOT="$PRUNE_DIR/root"
    nvim --headless "+lua local ok, err = pcall(function() local C = require('lazy.core.config'); local priv = vim.fn.stdpath('config') .. '/lua/config/private.lua'; if vim.uv.fs_stat(priv) then local pok, perr = pcall(dofile, priv); assert(pok, 'private.lua failed to load: ' .. tostring(perr)) end; for _, n in ipairs(C.spec and C.spec.notifs or {}) do assert(n.level < vim.log.levels.ERROR, 'plugin spec error: ' .. n.msg) end; require('lazy.core.plugin').update_state(); local d, c = {}, {}; for name, p in pairs(C.plugins) do d[#d + 1] = name; d[#d + 1] = vim.fs.basename(p.dir) end; for _, p in ipairs(C.to_clean) do c[#c + 1] = vim.fs.basename(p.dir) end; vim.fn.writefile(d, vim.env.NVIM_PRUNE_DECLARED); vim.fn.writefile(c, vim.env.NVIM_PRUNE_CANDIDATES); vim.fn.writefile({ C.options.root }, vim.env.NVIM_PRUNE_ROOT) end); if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit 1') end" "+lua -- prune-plugins" +qa || true
    if [[ -s "$NVIM_PRUNE_DECLARED" ]]; then
        PLUGIN_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
        [[ -s "$NVIM_PRUNE_ROOT" ]] && PLUGIN_ROOT="$(head -n 1 "$NVIM_PRUNE_ROOT")"
        "$BASH" "$SCRIPT_DIR/scripts/prune-plugins.sh" "$PLUGIN_ROOT" "$NVIM_PRUNE_DECLARED" "$NVIM_PRUNE_CANDIDATES" || true
    else
        printf 'Note: could not read the plugin list; no plugins were removed.\n'
    fi
fi

printf 'Installation complete: %s\n' "$NVIM_CONFIG_DIR"
printf 'Private customizations: lua/config/private.lua and lua/config/private_config.lua\n'
printf 'Open nvim to install plugins. Leader key: comma (,).\n'
