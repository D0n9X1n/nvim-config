#Requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Install', 'Test')][string]$Mode = 'Test')

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if ($env:OS -ne 'Windows_NT' -or $env:GITHUB_ACTIONS -ne 'true' -or -not $env:RUNNER_TEMP) {
    throw 'Dependency provisioning and integration tests require a disposable Windows GitHub runner.'
}
$repo = Split-Path -Parent $PSScriptRoot
$tools = Join-Path $env:RUNNER_TEMP 'nvim-dependencies'
$logs = Join-Path $env:RUNNER_TEMP 'dependency-logs'
$null = [IO.Directory]::CreateDirectory($tools)
$null = [IO.Directory]::CreateDirectory($logs)

function Invoke-Native([string]$Command, [string[]]$Arguments) {
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $Command @Arguments
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
    if ($code -ne 0) { throw "$Command failed with exit code $code" }
}

function Add-ToolPath([string]$Directory) {
    if (-not [IO.Directory]::Exists($Directory)) { throw "Tool directory missing: $Directory" }
    $env:PATH = $Directory + ';' + $env:PATH
    $Directory | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
}

if ($Mode -eq 'Install') {
    Start-Transcript -LiteralPath (Join-Path $logs 'install.log') | Out-Null
    try {
        $packages = [ordered]@{
            'ag' = '2.2.5'
            'ripgrep' = '15.2.0'
            'fzf' = '0.74.3'
            'universal-ctags' = '2022.06.05'
            'tree-sitter' = '0.27.0'
            'llvm' = '22.1.8'
            'nodejs-lts' = '24.21.0'
            'golang' = '1.27.1'
            'lua-language-server' = '3.18.2'
            'curl' = '8.22.0'
        }
        foreach ($package in $packages.Keys) {
            Invoke-Native 'choco.exe' @('upgrade', $package, ('--version=' + $packages[$package]),
                '--allow-downgrade', '--yes', '--no-progress', '--limit-output', '--execution-timeout=1200')
        }
        $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        $paths = ($env:PATH + ';' + $machinePath + ';' + $userPath) -split ';' | Where-Object {
            $_ -and $seen.Add($_.TrimEnd('\'))
        }
        $env:PATH = $paths -join ';'
        Add-ToolPath (Join-Path $env:ChocolateyInstall 'bin')
        Add-ToolPath (Join-Path $env:ProgramFiles 'LLVM\bin')
        Add-ToolPath (Join-Path $env:ProgramFiles 'nodejs')
        Add-ToolPath (Join-Path $env:ProgramFiles 'Go\bin')
        if ($env:PATH.Length -gt 7000) { throw 'Windows PATH is too long for npm cmd.exe lifecycle scripts.' }
        Invoke-Native 'cmd.exe' @('/d', '/c', 'node --version')
        $npm = Join-Path $tools 'npm'
        $null = [IO.Directory]::CreateDirectory($npm)
        Invoke-Native 'npm.cmd' @('install', '--global', '--prefix', $npm, '--no-audit', '--no-fund',
            'prettier@3.9.6', 'typescript@5.9.3', 'pyright@1.1.414',
            'bash-language-server@5.6.0', 'vscode-langservers-extracted@4.10.0',
            'yaml-language-server@1.24.0', 'graphql-language-service-cli@3.5.0',
            'vscode-solidity-server@0.0.187', '@olrtg/emmet-language-server@2.8.0')
        Add-ToolPath $npm
        $env:GOBIN = Join-Path $tools 'go-bin'
        $null = [IO.Directory]::CreateDirectory($env:GOBIN)
        Invoke-Native 'go.exe' @('install', 'golang.org/x/tools/gopls@v0.23.0')
        Add-ToolPath $env:GOBIN
        Invoke-Native 'python.exe' @('-m', 'pip', 'install', 'pynvim')
        foreach ($command in @('ag.exe', 'rg.exe', 'fzf.exe', 'ctags.exe', 'tree-sitter.exe', 'clang.exe',
                               'clangd.exe', 'node.exe', 'go.exe', 'gopls.exe', 'lua-language-server.exe', 'tar.exe', 'curl.exe')) {
            $resolved = Get-Command $command -CommandType Application -ErrorAction Stop
            Write-Host ($command + ' => ' + $resolved.Source)
        }
        foreach ($command in @('prettier.cmd', 'tsserver.cmd', 'pyright-langserver.cmd', 'bash-language-server.cmd',
                               'vscode-json-language-server.cmd', 'yaml-language-server.cmd', 'graphql-lsp.cmd',
                               'vscode-solidity-server.cmd', 'emmet-language-server.cmd')) {
            $null = Get-Command $command -CommandType Application -ErrorAction Stop
        }
        foreach ($command in @('ag.exe', 'rg.exe', 'fzf.exe', 'ctags.exe', 'tree-sitter.exe', 'clang.exe', 'clangd.exe',
                               'node.exe', 'lua-language-server.exe', 'tar.exe', 'curl.exe')) {
            Invoke-Native $command @('--version')
        }
        Invoke-Native 'go.exe' @('version')
        Invoke-Native 'gopls.exe' @('version')
        Invoke-Native 'npm.cmd' @('list', '--global', '--prefix', $npm, '--depth=0')
        "NVIM_DEPENDENCIES_NPM=$npm" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        "NPM_CONFIG_PREFIX=$npm" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        'CC=clang' | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        'CXX=clang++' | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
    } finally { Stop-Transcript | Out-Null }
} else {
    $env:NVIM_WINDOWS_REPO = $repo
    $env:NVIM_WINDOWS_SHELL = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell' } else { 'pwsh' }
    foreach ($probe in @('tools', 'servers')) {
        $env:NVIM_WINDOWS_DEPENDENCIES_MODE = $probe
        $env:NVIM_WINDOWS_SUCCESS = Join-Path $logs ($probe + '.passed')
        $env:NVIM_SMOKE_SUCCESS = Join-Path $logs ($probe + '.guard')
        foreach ($marker in @($env:NVIM_WINDOWS_SUCCESS, $env:NVIM_SMOKE_SUCCESS)) {
            if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker }
        }
        $previous = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $output = & nvim --headless -i NONE -n `
                --cmd 'lua vim.lsp.enable = function() end' `
                --cmd "lua dofile(vim.env.NVIM_WINDOWS_REPO .. '/scripts/smoke-guard.lua')" `
                -c "lua dofile(vim.env.NVIM_WINDOWS_REPO .. '/scripts/windows-dependencies.lua')" 2>&1
            $code = $LASTEXITCODE
        } finally { $ErrorActionPreference = $previous }
        $output | Tee-Object -FilePath (Join-Path $logs ($probe + '.log'))
        if ($code -ne 0 -or -not [IO.File]::Exists($env:NVIM_WINDOWS_SUCCESS) -or -not [IO.File]::Exists($env:NVIM_SMOKE_SUCCESS)) {
            throw "Windows dependency $probe probe failed"
        }
        if (($output -join "`n") -match '(?m)^Error\b|\bE\d{2,}:') { throw "Windows dependency $probe emitted an error" }
    }
}
