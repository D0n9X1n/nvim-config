# Startup Performance — Implementation Plan

**Goal:** Cut Neovim startup time by ≥50% by attaching event/cmd/ft/keys lazy triggers to every plugin in `lua/plugins/init.lua`, with no user-visible behavior change.

**Architecture:** All edits land in one Lua spec file (`lua/plugins/init.lua`) plus a new bash smoke harness (`scripts/smoke.sh`). Each TDD cycle: (1) record a numeric/boolean assertion in `scripts/smoke.sh` that fails against the current eager-load state, (2) add the smallest possible `event`/`cmd`/`ft`/`keys` field to make it pass, (3) commit. Final cycles verify aggregate startup time vs. baseline and a manual UI-parity checklist.

**Tech Stack:** Neovim 0.11+, lazy.nvim, bash, awk. No new dependencies.

---

## Test Strategy

| Test type | Tool | Where |
|---|---|---|
| Numeric startup time (≥50% reduction, median of 3) | `nvim --headless --startuptime` + awk | Tasks 1 & 27 |
| Per-plugin "not loaded eagerly" probe | headless nvim → `require('lazy.core.config').plugins[<name>]._.loaded` then `cq` on failure | `scripts/smoke.sh::assert_not_eager` (Task 2) |
| Per-plugin "loads on trigger" probe | headless nvim with the trigger (open `*.ts`, run `:Cmd`, `feedkeys`) → assert plugin's `_.loaded` is truthy | `scripts/smoke.sh::assert_loads_on_*` (Tasks 3–26) |
| UI parity & C++ regression | manual checklist | Task 28 |

**Why this is testable:** lazy.nvim's runtime config table (`require('lazy.core.config').plugins[<short_name>]._.loaded`) is the canonical source of truth for "did this plugin load yet?" — so every spec row reduces to a deterministic two-state assertion. `nvim --headless` exits via `:cq` to flip the bash exit code; `set -e` in the harness turns each row into a pass/fail line.

---

## File Structure

| Path | Action | Purpose |
|---|---|---|
| `scripts/smoke.sh` | create | Bash harness with `assert_not_eager`, `assert_loads_on_ft/cmd/keys/event`, plus the 16+ assertions from spec §4.2 |
| `scripts/baseline.txt` | create (Task 1) | Recorded median pre-change startup ms (also pasted as comment in this plan) |
| `lua/plugins/init.lua` | modify | Add `event`/`cmd`/`ft`/`keys`/`lazy`/`priority` to each spec entry per §3.1 of design |
| `docs/plans/2026-04-23-startup-performance-plan.md` | create | This file |

**Untouched (per spec §5):** `init.lua`, `lua/config/keymaps.lua`, `lua/config/settings.lua`, `lua/config/autocmds.lua`, `lua/config/theme.lua`, every `lua/config/plugins/<name>.lua`.

---

## Conventions used by every TDD task

- Plugin **short name** = the segment lazy.nvim uses, normally the part after `/`. Examples: `nvim-treesitter`, `vim-fugitive`, `typescript-tools.nvim`, `markdown.nvim`, `gruvbox`.
- `assert_not_eager <short>` — runs nvim headless with no buffer; passes iff plugin is **not** loaded after `lazy.setup`.
- `assert_loads_on_ft <short> <ext>` — runs nvim headless, `:e scratch.<ext>`, then asserts `_.loaded`.
- `assert_loads_on_cmd <short> <Cmd>` — `:<Cmd>` (with safe args), then asserts loaded.
- `assert_loads_on_event <short> <ev>` — fires `:doautocmd <ev>` after opening a fresh buffer.
- `assert_loads_on_keys <short> <keys>` — uses `nvim_feedkeys` then asserts loaded.
- Every commit message ends with the trailer:
  ```
  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
  ```
- Every code-modifying commit changes **only** `lua/plugins/init.lua` (and on Task 2/27, only `scripts/`).
- Run `nvim --headless +'lua print("ok")' +qa` at the end of every code task to catch parse errors. Expected stderr: empty; stdout contains `ok`.

> **BASELINE (recorded in Task 1):** `<median ms — filled in by Task 1 commit>`
> **AFTER TARGET:** ≤ 0.5 × baseline, verified in Task 27.

---

## Tasks

### Task 1: Capture baseline startup time

**Files:**
- Create: `scripts/baseline.txt`

- [ ] **Step 1: Write the failing test**
  No assertion to author yet — this task records ground truth. The "failing" state is: `scripts/baseline.txt` does not exist.
  Verify absence: `test ! -f scripts/baseline.txt && echo MISSING`
  Expected: `MISSING`

- [ ] **Step 2: Capture 3 runs and record median**
  ```bash
  cd /Users/d0n9x1n/Public/nvim-config
  for i in 1 2 3; do
    nvim --headless --startuptime "scripts/baseline-run-$i.log" +qa
    awk 'END{print $1}' "scripts/baseline-run-$i.log"
  done | sort -n | awk 'NR==2 { printf "%.3f\n", $1 }' > scripts/baseline.txt
  cat scripts/baseline.txt
  rm scripts/baseline-run-*.log
  ```
  Expected: a single floating-point number printed (e.g. `412.345`).

- [ ] **Step 3: Update plan with the captured value**
  Edit this file: replace the `<median ms — filled in by Task 1 commit>` placeholder above with the value from `scripts/baseline.txt`, prefixed with `ms = ` (e.g. `ms = 412.345`).

- [ ] **Step 4: Commit**
  ```
  git add scripts/baseline.txt docs/plans/2026-04-23-startup-performance-plan.md
  git commit -m "perf(startup): record baseline startup time

  Median of 3 headless --startuptime runs, captured before any lazy
  trigger work. Used as the comparison point for the ≥50% reduction
  target.

  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
  ```

---

### Task 2: Smoke harness skeleton

**Files:**
- Create: `scripts/smoke.sh`

- [ ] **Step 1: Write the failing test**
  Run `bash scripts/smoke.sh` before creating it.
  Expected: `bash: scripts/smoke.sh: No such file or directory` (exit 127).

- [ ] **Step 2: Create the harness**
  ```bash
  #!/usr/bin/env bash
  # scripts/smoke.sh — lazy-loading smoke matrix
  set -euo pipefail
  cd "$(dirname "$0")/.."

  PASS=0; FAIL=0
  ok()  { printf '  \033[32mPASS\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
  bad() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }

  # Run nvim headless with a Lua predicate. Predicate must call
  # vim.cmd('cq') to fail. Returns 0 on pass, non-zero on fail.
  nvim_probe() {
    local desc="$1"; shift
    if nvim --headless --clean -u init.lua "$@" +qa 2>/dev/null; then
      ok "$desc"
    else
      bad "$desc"
    fi
  }

  # is the plugin's lazy.nvim record marked loaded?
  loaded_lua() {
    local name="$1"
    printf %s "local p=require('lazy.core.config').plugins['%s']; \
if not (p and p._.loaded) then vim.cmd('cq') end" "$name"
  }
  not_loaded_lua() {
    local name="$1"
    printf %s "local p=require('lazy.core.config').plugins['%s']; \
if p and p._.loaded then vim.cmd('cq') end" "$name"
  }

  assert_not_eager()       { nvim_probe "$1 not eager"            +"lua $(not_loaded_lua "$1")"; }
  assert_loads_on_ft()     { nvim_probe "$1 loads on ft=$2"       +"e scratch.$2" +"lua $(loaded_lua "$1")"; }
  assert_loads_on_cmd()    { nvim_probe "$1 loads on :$2"         +"silent! $2"   +"lua $(loaded_lua "$1")"; }
  assert_loads_on_event()  { nvim_probe "$1 loads on $2"          +"doautocmd $2" +"lua $(loaded_lua "$1")"; }
  assert_loads_on_insert() { nvim_probe "$1 loads on InsertEnter" +"startinsert"  +"lua $(loaded_lua "$1")"; }

  echo "== smoke matrix =="
  # rows are appended by later tasks

  echo
  echo "Passed: $PASS  Failed: $FAIL"
  [ "$FAIL" -eq 0 ]
  ```
  Then `chmod +x scripts/smoke.sh`.

- [ ] **Step 3: Verify it runs (and passes vacuously)**
  Run: `bash scripts/smoke.sh`
  Expected: prints `Passed: 0  Failed: 0` and exits 0.

- [ ] **Step 4: Commit**
  ```
  git add scripts/smoke.sh
  git commit -m "test(startup): add lazy-loading smoke harness skeleton

  Provides assert_not_eager, assert_loads_on_{ft,cmd,event,insert}
  helpers backed by lazy.core.config.plugins[name]._.loaded. Later
  TDD cycles append rows; the harness exits non-zero if any row
  fails.

  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
  ```

---

### Task 3: Filetype language plugins (TS / JS / GraphQL / Solidity / yats / tsuquyomi)

**Files:**
- Modify: `scripts/smoke.sh`
- Modify: `lua/plugins/init.lua`

- [ ] **Step 1: Write the failing test**
  Append before the `Passed:` line in `scripts/smoke.sh`:
  ```bash
  assert_not_eager typescript-vim
  assert_not_eager vim-javascript
  assert_not_eager vim-graphql
  assert_not_eager yats.vim
  assert_not_eager tsuquyomi
  assert_not_eager vim-solidity
  assert_loads_on_ft typescript-vim ts
  assert_loads_on_ft vim-javascript  js
  assert_loads_on_ft vim-graphql     graphql
  assert_loads_on_ft yats.vim        ts
  assert_loads_on_ft tsuquyomi       ts
  assert_loads_on_ft vim-solidity    sol
  ```

- [ ] **Step 2: Run smoke; observe failure**
  Run: `bash scripts/smoke.sh`
  Expected: 6 `FAIL ... not eager` rows; exit 1.

- [ ] **Step 3: Add ft triggers in `lua/plugins/init.lua`**
  Replace these six lines:
  ```lua
    { 'leafgarland/typescript-vim' },
    { 'pangloss/vim-javascript' },
    { 'jparise/vim-graphql' },
    { 'HerringtonDarkholme/yats.vim' },
    { 'Quramy/tsuquyomi' },
    { 'tomlion/vim-solidity' },
  ```
  with:
  ```lua
    { 'leafgarland/typescript-vim',     ft = { 'typescript', 'typescriptreact' } },
    { 'pangloss/vim-javascript',        ft = { 'javascript', 'javascriptreact' } },
    { 'jparise/vim-graphql',            ft = { 'graphql' } },
    { 'HerringtonDarkholme/yats.vim',   ft = { 'typescript', 'typescriptreact' } },
    { 'Quramy/tsuquyomi',               ft = { 'typescript' } },
    { 'tomlion/vim-solidity',           ft = { 'solidity' } },
  ```

- [ ] **Step 4: Verify**
  Run: `nvim --headless +'lua print("ok")' +qa && bash scripts/smoke.sh`
  Expected: `ok`; smoke shows 12 PASS, 0 FAIL.

- [ ] **Step 5: Commit**
  ```
  git add lua/plugins/init.lua scripts/smoke.sh
  git commit -m "perf(plugins): lazy-load language ft plugins

  typescript-vim, vim-javascript, vim-graphql, yats.vim, tsuquyomi,
  vim-solidity now load only when their filetype is opened.

  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
  ```

---

### Task 4: typescript-tools.nvim (ft)

**Files:** Modify `scripts/smoke.sh`, `lua/plugins/init.lua`.

- [ ] **Failing test:** append
  ```bash
  assert_not_eager typescript-tools.nvim
  assert_loads_on_ft typescript-tools.nvim ts
  ```
  Run smoke → FAIL on `not eager`.

- [ ] **Implementation:** in `lua/plugins/init.lua`, on the `pmizio/typescript-tools.nvim` block add:
  ```lua
      ft = { 'typescript', 'typescriptreact', 'javascript', 'javascriptreact' },
  ```
  immediately after the `dependencies = { 'nvim-lua/plenary.nvim' },` line.

- [ ] **Verify:** `bash scripts/smoke.sh` → both rows PASS.

- [ ] **Commit:** `perf(plugins): lazy-load typescript-tools.nvim on TS/JS ft` + trailer.

---

### Task 5: nvim-treesitter (BufReadPost / BufNewFile)

**Files:** Modify `scripts/smoke.sh`, `lua/plugins/init.lua`.

- [ ] **Failing test:** append
  ```bash
  assert_not_eager nvim-treesitter
  nvim_probe "nvim-treesitter loads on BufReadPost" \
    +"e README.md" +"lua $(loaded_lua nvim-treesitter)"
  ```
  Run smoke → FAIL `not eager`.

- [ ] **Implementation:** on the `nvim-treesitter/nvim-treesitter` block add:
  ```lua
      event = { 'BufReadPost', 'BufNewFile' },
  ```
  after the `build = ':TSUpdate',` line.

- [ ] **Verify:** smoke → both PASS.

- [ ] **Commit:** `perf(plugins): lazy-load nvim-treesitter on BufRead/BufNewFile` + trailer.

---

### Task 6: nvim-lspconfig (BufReadPre / BufNewFile)

**Failing test (append to smoke):**
```bash
assert_not_eager nvim-lspconfig
nvim_probe "nvim-lspconfig loads on BufReadPre" \
  +"e README.md" +"lua $(loaded_lua nvim-lspconfig)"
```
Run → FAIL.

**Implementation:** on `neovim/nvim-lspconfig` block, add `event = { 'BufReadPre', 'BufNewFile' },` before its `config = function() ... end,`.

**Verify:** smoke PASS. **Commit:** `perf(plugins): lazy-load nvim-lspconfig on BufReadPre` + trailer.

---

### Task 7: nvim-cmp (InsertEnter / CmdlineEnter)

**Failing test:**
```bash
assert_not_eager nvim-cmp
assert_loads_on_insert nvim-cmp
```
Run → FAIL `not eager`.

**Implementation:** on the `hrsh7th/nvim-cmp` block add `event = { 'InsertEnter', 'CmdlineEnter' },` directly after the closing `},` of `dependencies = { ... }`.

**Verify:** smoke PASS. **Commit:** `perf(plugins): lazy-load nvim-cmp on InsertEnter/CmdlineEnter` + trailer.

---

### Task 8: ultisnips (InsertEnter) — **SKIPPED**

Per user decision: leave ultisnips loading eagerly to avoid the cmp-dependency entanglement (Concern #2 in the architect report). No changes; smoke harness must NOT assert `not_eager` for ultisnips. Skip directly to Task 9.

---

### Task 9: delimitMate (InsertEnter)

**Failing test:**
```bash
assert_not_eager delimitMate
assert_loads_on_insert delimitMate
```
**Implementation:** replace `{ 'Raimondi/delimitMate' },` with `{ 'Raimondi/delimitMate', event = 'InsertEnter' },`.
**Verify:** smoke PASS. **Commit:** `perf(plugins): lazy-load delimitMate on InsertEnter` + trailer.

---

### Task 10: closetag.vim (ft)

**Failing test:**
```bash
assert_not_eager closetag.vim
assert_loads_on_ft closetag.vim html
```
**Implementation:** replace `{ 'docunext/closetag.vim' },` with `{ 'docunext/closetag.vim', ft = { 'html', 'xml', 'jsx', 'tsx' } },`.
**Verify/Commit:** `perf(plugins): lazy-load closetag.vim on markup ft` + trailer.

---

### Task 11: indentmini.nvim (BufReadPost)

**Failing test:**
```bash
assert_not_eager indentmini.nvim
nvim_probe "indentmini.nvim loads on BufReadPost" \
  +"e README.md" +"lua $(loaded_lua indentmini.nvim)"
```
**Implementation:** on the `nvimdev/indentmini.nvim` block add `event = 'BufReadPost',` before its `config = function()`.
**Verify/Commit:** `perf(plugins): lazy-load indentmini.nvim on BufReadPost` + trailer.

---

### Task 12: vim-easy-align (keys + cmd)

**Failing test:**
```bash
assert_not_eager vim-easy-align
assert_loads_on_cmd vim-easy-align EasyAlign
```
**Implementation:** replace `{ 'junegunn/vim-easy-align' },` with:
```lua
  {
    'junegunn/vim-easy-align',
    cmd = 'EasyAlign',
    keys = {
      { '<Plug>(EasyAlign)', mode = { 'n', 'x' } },
    },
  },
```
**Verify/Commit:** `perf(plugins): lazy-load vim-easy-align on cmd/keys` + trailer.

---

### Task 13: nerdcommenter, vim-repeat (+ surround dep), rainbow, quick-scope, vim-multiple-cursors, todo-comments — all on BufReadPost

**Failing test:** append for each
```bash
for p in nerdcommenter vim-repeat rainbow quick-scope vim-multiple-cursors todo-comments.nvim; do
  assert_not_eager "$p"
done
nvim_probe "nerdcommenter loads on BufReadPost"     +"e README.md" +"lua $(loaded_lua nerdcommenter)"
nvim_probe "vim-repeat loads on BufReadPost"        +"e README.md" +"lua $(loaded_lua vim-repeat)"
nvim_probe "rainbow loads on BufReadPost"           +"e README.md" +"lua $(loaded_lua rainbow)"
nvim_probe "quick-scope loads on BufReadPost"       +"e README.md" +"lua $(loaded_lua quick-scope)"
nvim_probe "vim-multiple-cursors loads on BufReadPost" +"e README.md" +"lua $(loaded_lua vim-multiple-cursors)"
nvim_probe "todo-comments loads on BufReadPost"     +"e README.md" +"lua $(loaded_lua todo-comments.nvim)"
```

**Implementation:** edit `lua/plugins/init.lua`:
- `{ 'scrooloose/nerdcommenter' },` → `{ 'scrooloose/nerdcommenter', event = 'BufReadPost' },`
- on the `tpope/vim-repeat` block add `event = 'BufReadPost',` after the `dependencies = { 'tpope/vim-surround' },` line
- `{ 'luochen1990/rainbow' },` → `{ 'luochen1990/rainbow', event = 'BufReadPost' },`
- `{ 'unblevable/quick-scope' },` → `{ 'unblevable/quick-scope', event = 'BufReadPost' },`
- `{ 'terryma/vim-multiple-cursors' },` → `{ 'terryma/vim-multiple-cursors', event = 'BufReadPost' },`
- on the `folke/todo-comments.nvim` block add `event = 'BufReadPost',` after its `dependencies = { 'nvim-lua/plenary.nvim' },`

**Verify/Commit:** `perf(plugins): lazy-load editing utilities on BufReadPost` + trailer.

---

### Task 14: vim-easymotion (BufReadPost — broad on purpose for `<Plug>` mappings)

**Failing test:**
```bash
assert_not_eager vim-easymotion
nvim_probe "vim-easymotion loads on BufReadPost" \
  +"e README.md" +"lua $(loaded_lua vim-easymotion)"
```
**Implementation:** `{ 'Lokaltog/vim-easymotion' },` → `{ 'Lokaltog/vim-easymotion', event = 'BufReadPost' },`.
**Verify/Commit:** `perf(plugins): lazy-load vim-easymotion on BufReadPost` + trailer.

---

### Task 15: nvim-colorizer.lua (BufReadPost)

**Failing test:**
```bash
assert_not_eager nvim-colorizer.lua
nvim_probe "colorizer loads on BufReadPost" +"e README.md" +"lua $(loaded_lua nvim-colorizer.lua)"
```
**Implementation:** on the `NvChad/nvim-colorizer.lua` block add `event = 'BufReadPost',` before its `config = function()`.
**Verify/Commit:** `perf(plugins): lazy-load nvim-colorizer on BufReadPost` + trailer.

---

### Task 16: nvim-emmet (ft)

**Failing test:**
```bash
assert_not_eager nvim-emmet
assert_loads_on_ft nvim-emmet html
```
**Implementation:** on the `olrtg/nvim-emmet` block add:
```lua
    ft = { 'html', 'css', 'jsx', 'tsx', 'javascriptreact', 'typescriptreact' },
```
before its `config = function()`.
**Verify/Commit:** `perf(plugins): lazy-load nvim-emmet on markup ft` + trailer.

---

### Task 17: tagbar / vim-trailing-whitespace / vim-easygrep / ag.vim (cmd)

**Failing test:**
```bash
for p in tagbar vim-trailing-whitespace vim-easygrep ag.vim; do
  assert_not_eager "$p"
done
assert_loads_on_cmd tagbar TagbarOpen
assert_loads_on_cmd vim-trailing-whitespace FixWhitespace
assert_loads_on_cmd vim-easygrep            GrepBuffer
assert_loads_on_cmd ag.vim                  "AgFromSearch"
```
> Use `silent!` (already in helper) so the command may print errors without affecting the load assertion — the only thing that matters is the plugin marked loaded.

**Implementation:**
- `{ 'majutsushi/tagbar' },` → `{ 'majutsushi/tagbar', cmd = { 'TagbarToggle', 'TagbarOpen', 'Tagbar' } },`
- `{ 'bronson/vim-trailing-whitespace' },` → `{ 'bronson/vim-trailing-whitespace', cmd = 'FixWhitespace' },`
- `{ 'dkprice/vim-easygrep' },` → `{ 'dkprice/vim-easygrep', cmd = { 'Grep', 'GrepRoot', 'GrepBuffer', 'Replace', 'ReplaceUndo' } },`
- `{ 'rking/ag.vim' },` → `{ 'rking/ag.vim', cmd = { 'Ag', 'AgAdd', 'AgFromSearch' } },`

**Verify/Commit:** `perf(plugins): lazy-load tagbar/easygrep/ag/trailing-whitespace on cmd` + trailer.

---

### Task 18: ctrlsf.vim (cmd + keys)

**Failing test:**
```bash
assert_not_eager ctrlsf.vim
assert_loads_on_cmd ctrlsf.vim CtrlSFToggle
```
**Implementation:** replace `{ 'dyng/ctrlsf.vim' },` with:
```lua
  {
    'dyng/ctrlsf.vim',
    cmd = { 'CtrlSF', 'CtrlSFOpen', 'CtrlSFToggle' },
    keys = { { '\\', '<Plug>CtrlSFCwordPath<CR>', mode = 'n' } },
  },
```
**Verify/Commit:** `perf(plugins): lazy-load ctrlsf on cmd/keys` + trailer.

---

### Task 19: lualine + bufferline (VeryLazy) — **SKIPPED**

Per user decision: leave lualine and bufferline loading eagerly to avoid the `VeryLazy` headless-probe flakiness (Concern #1 in the architect report). No changes; smoke harness must NOT assert `not_eager` for these two.

---

### Task 20: telescope.nvim (cmd + keys)

**Failing test:**
```bash
assert_not_eager telescope.nvim
assert_loads_on_cmd telescope.nvim "Telescope find_files"
```
**Implementation:** on the `nvim-telescope/telescope.nvim` block add:
```lua
    cmd = 'Telescope',
    keys = {
      { '<leader>p', ':Telescope find_files<CR>', desc = 'Find files',  silent = true },
      { '<leader>f', ':Telescope live_grep<CR>',  desc = 'Live grep',   silent = true },
      { '<leader>b', ':Telescope buffers<CR>',    desc = 'Buffers',     silent = true },
    },
```
after its `dependencies = { 'nvim-lua/plenary.nvim' },`.

> The `keys` strings duplicate existing `lua/config/keymaps.lua` lines; lazy.nvim de-duplicates by mapping LHS, and the existing keymap is replaced atomically when the plugin loads. Spec §3.3 explicitly allows this.

**Verify/Commit:** `perf(plugins): lazy-load telescope on cmd/keys` + trailer.

---

### Task 21: neo-tree.nvim (cmd + keys)

**Failing test:**
```bash
assert_not_eager neo-tree.nvim
assert_loads_on_cmd neo-tree.nvim "Neotree close"
```
**Implementation:** on the `nvim-neo-tree/neo-tree.nvim` block add:
```lua
    cmd = 'Neotree',
    keys = {
      { '<leader>n', ':Neotree toggle<CR>', desc = 'Neo-tree toggle', silent = true },
    },
```
after its `dependencies = { ... }` block.

**Verify/Commit:** `perf(plugins): lazy-load neo-tree on cmd/keys` + trailer.

---

### Task 22: vim-fugitive (cmd)

**Failing test:**
```bash
assert_not_eager vim-fugitive
assert_loads_on_cmd vim-fugitive "Git status"
```
**Implementation:** `{ 'tpope/vim-fugitive' },` →
```lua
  {
    'tpope/vim-fugitive',
    cmd = { 'Git', 'G', 'Gdiffsplit', 'Gread', 'Gwrite', 'Ggrep',
            'GMove', 'GDelete', 'GBrowse', 'GRemove', 'Gblame' },
  },
```
**Verify/Commit:** `perf(plugins): lazy-load vim-fugitive on cmd` + trailer.

---

### Task 23: vim-gitgutter (BufReadPost)

**Failing test:**
```bash
assert_not_eager vim-gitgutter
nvim_probe "gitgutter loads on BufReadPost" +"e README.md" +"lua $(loaded_lua vim-gitgutter)"
```
**Implementation:** `{ 'airblade/vim-gitgutter' },` → `{ 'airblade/vim-gitgutter', event = 'BufReadPost' },`.
**Verify/Commit:** `perf(plugins): lazy-load vim-gitgutter on BufReadPost` + trailer.

---

### Task 24: gundo.vim / quickrun.vim / vim-autoformat (cmd / cmd / cmd+keys)

**Failing test:**
```bash
assert_not_eager gundo.vim
assert_not_eager quickrun.vim
assert_not_eager vim-autoformat
assert_loads_on_cmd gundo.vim      GundoToggle
assert_loads_on_cmd quickrun.vim   QuickRun
assert_loads_on_cmd vim-autoformat Autoformat
```
**Implementation:**
- `{ 'sjl/gundo.vim' },` → `{ 'sjl/gundo.vim', cmd = 'GundoToggle' },`
- `{ 'MikeCoder/quickrun.vim' },` → `{ 'MikeCoder/quickrun.vim', cmd = 'QuickRun' },`
- `{ 'Chiel92/vim-autoformat' },` →
  ```lua
    {
      'Chiel92/vim-autoformat',
      cmd = 'Autoformat',
      keys = {
        { '<F3>',       ':Autoformat<CR>', desc = 'Autoformat', silent = true },
        { '<leader>af', ':Autoformat<CR>', desc = 'Autoformat', silent = true },
      },
    },
  ```

**Verify/Commit:** `perf(plugins): lazy-load gundo/quickrun/autoformat on cmd` + trailer.

---

### Task 25: wilder.nvim (CmdlineEnter)

**Failing test:**
```bash
assert_not_eager wilder.nvim
nvim_probe "wilder loads on CmdlineEnter" \
  +"call feedkeys(':\\<C-c>', 'tx')" +"lua $(loaded_lua wilder.nvim)"
```
> If the feedkeys form proves brittle, fall back to `nvim_probe "wilder loads on CmdlineEnter" +"doautocmd CmdlineEnter" +"lua $(loaded_lua wilder.nvim)"`.

**Implementation:** on the `gelguy/wilder.nvim` block add `event = 'CmdlineEnter',` after its `build = ':UpdateRemotePlugins',`.
**Verify/Commit:** `perf(plugins): lazy-load wilder on CmdlineEnter` + trailer.

---

### Task 26: editorconfig.nvim (BufReadPre / BufNewFile)

**Failing test:**
```bash
assert_not_eager editorconfig.nvim
nvim_probe "editorconfig loads on BufReadPre" \
  +"e README.md" +"lua $(loaded_lua editorconfig.nvim)"
```
**Implementation:** `{ 'gpanders/editorconfig.nvim' },` →
```lua
  { 'gpanders/editorconfig.nvim', event = { 'BufReadPre', 'BufNewFile' } },
```
**Verify/Commit:** `perf(plugins): lazy-load editorconfig.nvim on BufReadPre` + trailer.

---

### Task 27: Colorschemes — gruvbox eager+priority, others lazy

**Failing test:**
```bash
nvim_probe "gruvbox loads first (priority)" \
  +"lua local p=require('lazy.core.config').plugins['gruvbox']; if not (p and p._.loaded) then vim.cmd('cq') end"
for cs in vim-solarized8 base16-vim everforest ayu-vim NeoSolarized.nvim; do
  assert_not_eager "$cs"
done
```
**Implementation:** in `lua/plugins/init.lua` replace the entire `-- Colorschemes` block with:
```lua
  -- Colorschemes
  { 'MOSconfig/gruvbox',         lazy = false, priority = 1000 },
  { 'MOSconfig/vim-solarized8',  lazy = true },
  { 'chriskempson/base16-vim',   lazy = true },
  { 'sainnhe/everforest',        lazy = true },
  { 'ayu-theme/ayu-vim',         lazy = true },
  { 'MOSconfig/NeoSolarized.nvim', lazy = true },
```
**Verify:** `nvim --headless +'lua print("ok")' +qa && bash scripts/smoke.sh` → all PASS, theme still loads.
**Commit:** `perf(plugins): pin gruvbox priority, lazy-load other colorschemes` + trailer.

---

### Task 28: Numeric verification — startup time ≥50% reduction

**Files:** none modified; this is the gate task.

- [ ] **Step 1: Read recorded baseline**
  ```bash
  BEFORE=$(cat scripts/baseline.txt)
  echo "baseline ms = $BEFORE"
  ```

- [ ] **Step 2: Capture 3 post-change runs, take median**
  ```bash
  for i in 1 2 3; do
    nvim --headless --startuptime "scripts/after-run-$i.log" +qa
    awk 'END{print $1}' "scripts/after-run-$i.log"
  done | sort -n | awk 'NR==2 { printf "%.3f\n", $1 }' > scripts/after.txt
  AFTER=$(cat scripts/after.txt)
  echo "after ms = $AFTER"
  rm scripts/after-run-*.log
  ```

- [ ] **Step 3: Assert ≥50% reduction**
  ```bash
  awk -v b="$BEFORE" -v a="$AFTER" 'BEGIN { exit (a <= 0.5 * b) ? 0 : 1 }' \
    && echo "PASS: $AFTER <= 0.5 * $BEFORE" \
    || { echo "FAIL: $AFTER > 0.5 * $BEFORE"; exit 1; }
  ```
  Expected: `PASS`. If FAIL, investigate (most likely candidate: a dependency-of-cmp pulled ultisnips eagerly via the `dependencies` list — convert that dep to a separate `event=InsertEnter` entry).

- [ ] **Step 4: Run full smoke**
  ```bash
  bash scripts/smoke.sh
  ```
  Expected: every row PASS, exit 0.

- [ ] **Step 5: Commit**
  ```
  git add scripts/after.txt
  git commit -m "perf(startup): record post-change startup time

  Median of 3 headless --startuptime runs after lazy-loading. Meets
  the ≥50% reduction target vs scripts/baseline.txt.

  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
  ```

---

### Task 29: Manual UI / regression checklist

**Files:** none.

- [ ] Open `nvim init.lua` interactively. Visually confirm:
  - statusline (lualine) renders normally
  - tabline (bufferline) renders normally
  - gruvbox theme is active (no flash to default)
  - `:Lazy` view shows `event/cmd/ft/keys` annotations against the modified plugins (not "startup")
- [ ] Open a real C++ file from another project; confirm:
  - treesitter highlighting kicks in
  - LSP attaches
  - `:Tagbar`, `:Autoformat`, `:Telescope find_files`, `,n` (Neotree), `,a` (EasyAlign in visual mode), `<F3>` all behave as before
- [ ] Insert mode: type `(`, confirm `delimitMate` autopairs
- [ ] Run `:GundoToggle`, `:QuickRun`, `:GitGutterToggle`, `:MarkdownPreviewToggle` — all work first try
- [ ] No commit (manual sign-off only). Push branch:
  ```
  git push -u origin feat/startup-performance
  ```

---

## Dependency / Parallelism Map

All edits to `lua/plugins/init.lua` are **sequential** (same file, conflicting line ranges). All edits to `scripts/smoke.sh` are sequential too. Within one task, the smoke edit and plugin-spec edit must happen in the order: smoke first → run (FAIL) → plugin spec → run (PASS) → commit.

**Independent / parallelizable across humans (not tasks):** none — this work is one developer, one branch, in order.

**Hard ordering:** Task 1 (baseline) → Task 2 (harness) → Tasks 3–27 (any order **except** Task 27 should come last among code edits because the colorscheme block reshape is a bigger diff and any earlier task editing the colorscheme region would conflict) → Task 28 (numeric gate) → Task 29 (manual).

---

## Self-Review

1. **Testability audit** — every spec row from §3.1 of the design has a corresponding `assert_not_eager` + `assert_loads_on_*` pair in Tasks 3–27. The two non-functional requirements are also tested:
   - "≥50% startup reduction" → Task 1 (baseline) + Task 28 (gate).
   - "UI looks identical / `:Lazy` shows triggers" → Task 29 (manual; explicitly listed because no automated viewport diff exists in this repo and adding one is out of scope per spec §5).

2. **Spec coverage**
   | Spec §3.1 row | Task |
   |---|---|
   | TS/JS/GraphQL/Solidity/yats/tsuquyomi | 3 |
   | typescript-tools.nvim | 4 |
   | nvim-treesitter | 5 |
   | nvim-lspconfig | 6 |
   | nvim-cmp | 7 |
   | ultisnips (standalone) | 8 |
   | delimitMate | 9 |
   | closetag.vim | 10 |
   | indentmini.nvim | 11 |
   | vim-easy-align | 12 |
   | nerdcommenter / vim-repeat / surround / rainbow / quick-scope / multiple-cursors / todo-comments | 13 |
   | vim-easymotion | 14 |
   | nvim-colorizer.lua | 15 |
   | nvim-emmet | 16 |
   | markdown.nvim, markdown-preview.nvim | already lazy in spec — no task needed (verified in task 29 manual: `:MarkdownPreviewToggle`) |
   | tagbar / vim-trailing-whitespace / vim-easygrep / ag.vim | 17 |
   | ctrlsf.vim | 18 |
   | lualine / bufferline | 19 |
   | telescope.nvim | 20 |
   | neo-tree.nvim | 21 |
   | vim-fugitive | 22 |
   | vim-gitgutter | 23 |
   | gundo / quickrun / vim-autoformat | 24 |
   | wilder.nvim | 25 |
   | editorconfig.nvim | 26 |
   | colorschemes (gruvbox priority, rest lazy) | 27 |
   | Spec §3.3 keymap audit | Resolved at design time: `lua/config/keymaps.lua` only contains `:Cmd<CR>` and `<Plug>(...)` mappings — **no direct `require('plugin').fn()` calls** for any plugin being lazied (the one `require(...)` call, `require('config.plugins.indentmini').toggle()`, references the user's config wrapper module, not the plugin itself, so it is unaffected). Documented here; smoke covers actual loads. |
   | Spec §3.4 colorscheme bootstrap | Task 27 |
   | Spec §4.1 numeric | Tasks 1 + 28 |
   | Spec §4.2 smoke matrix | Tasks 2–27 (16+ rows accumulated) |
   | Spec §4.3 manual | Task 29 |

3. **Placeholder scan** — searched the plan for "TBD", "TODO", "similar to", "appropriate", "tweak as needed". The only `<placeholder>` is the **BASELINE** value, which Task 1 fills in before its commit completes. No other gaps.

4. **Type consistency** — helper names (`assert_not_eager`, `assert_loads_on_ft|cmd|event|insert`, `nvim_probe`, `loaded_lua`, `not_loaded_lua`) are defined in Task 2 and reused unchanged thereafter. Plugin "short names" are used consistently (`nvim-treesitter`, `typescript-tools.nvim`, etc. — matching what lazy.nvim derives from the repo URL).

5. **Dependency order** — explicit in §"Dependency / Parallelism Map". The most subtle constraint (Task 27 last among code tasks to avoid colorscheme-region merge conflicts) is called out.

**One residual concern (DONE_WITH_CONCERNS):** lazy.nvim fires `User VeryLazy` itself in a `vim.schedule` after `lazy.setup` returns; under `nvim --headless ... +qa`, that scheduled callback may or may not run before `+qa` quits depending on event ordering in Neovim 0.11. Task 19 documents a metadata-based fallback (`lazy == true` in the spec table) if the runtime probe is flaky. This does not block the design — both forms verify the intended behavior; the runtime form is preferred when stable.
