#!/usr/bin/env bash
set -euo pipefail

if [[ ${GITHUB_ACTIONS:-} != true || -z ${RUNNER_TEMP:-} ]]; then
  printf 'Run the existing scripts/smoke.sh locally; CI bootstrap requires a disposable GitHub runner.\n' >&2
  exit 1
fi
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
STATE=$(mktemp -d "$RUNNER_TEMP/nvim-unix.XXXXXX")
export XDG_CONFIG_HOME="$STATE/config" XDG_DATA_HOME="$STATE/data"
export XDG_STATE_HOME="$STATE/state" XDG_CACHE_HOME="$STATE/cache"
export NVIM_CI_REPO="$ROOT" NVIM_SMOKE_SUCCESS="$STATE/setup.passed"
unset NVIM_APPNAME NVIM_SMOKE_BUFFERLINE_SOURCE NVIM_RPLUGIN_MANIFEST NVIM_LOG_FILE
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"
LOGS="$RUNNER_TEMP/nvim-unix-logs"
mkdir -p "$LOGS"
exec > >(tee "$LOGS/bootstrap.log") 2>&1
for tool in nvim git python3 rg ag fzf ctags; do
  command -v "$tool" >/dev/null || { printf 'Missing prerequisite: %s\n' "$tool" >&2; exit 1; }
done
nvim --version
python3 --version
python3 -c 'import pynvim'
rg --version
ag --version
fzf --version
ctags --version
bash "$ROOT/install.sh" --no-deps
nvim --headless -i NONE -n \
  --cmd "lua dofile(vim.env.NVIM_CI_REPO .. '/scripts/smoke-guard.lua')" \
  -c 'Lazy! sync' \
  -c "lua _G.smoke_command([[lua for name,p in pairs(require('lazy.core.config').plugins) do assert(p._.installed, name .. ' missing'); for _,task in ipairs(p._.tasks or {}) do assert(not task:has_errors(), name .. ': ' .. task:output()) end end]])" \
  -c "lua _G.smoke_command([[lua assert(vim.fn.has('python3') == 1, 'Python provider missing'); vim.cmd('enew'); vim.bo.filetype='lua'; assert(vim.treesitter.get_parser(0), 'bundled Lua parser missing')]])" \
  -c 'lua _G.smoke_finish()' -c 'qa!' | tee "$LOGS/plugin-setup.log"
test -f "$NVIM_SMOKE_SUCCESS"
python3 - "$XDG_CONFIG_HOME/nvim/lazy-lock.json" <<'PY'
import json, pathlib, sys
lock = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert lock, 'Plugin lockfile is empty'
for name, entry in sorted(lock.items()):
    print(f'{name}: {entry["branch"]} {entry["commit"]}')
PY
nvim --headless -u NONE -i NONE -n \
  "+lua local ok,e=pcall(function() assert(loadfile('init.lua')); for _,f in ipairs(vim.fn.systemlist('git ls-files lua')) do assert(loadfile(f),f) end end); if not ok then print(e); vim.cmd('cquit 1') end" +qa
NVIM_WINDOWS_REPO="$ROOT" nvim --headless -u NONE -i NONE -n -l "$ROOT/scripts/windows-regression.lua"
bash "$ROOT/scripts/smoke.sh" 2>&1 | tee "$LOGS/smoke.log"
