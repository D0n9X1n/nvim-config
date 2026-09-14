[CmdletBinding()]
param([switch]$Integration)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if ($env:OS -ne 'Windows_NT') { throw 'These tests require native Windows.' }
$repo = Split-Path -Parent $PSScriptRoot
$nvim = (Get-Command nvim -ErrorAction Stop).Source
$temp = Join-Path ([IO.Path]::GetTempPath()) ('nvim-windows-tests-' + [guid]::NewGuid().ToString('N'))
$null = [IO.Directory]::CreateDirectory($temp)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$saved = @{}
foreach ($name in @('XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME', 'NVIM_APPNAME', 'NVIM_LOG_FILE', 'NVIM_WINDOWS_REPO', 'NVIM_WINDOWS_TEST_MODE', 'NVIM_WINDOWS_SHELL', 'NVIM_WINDOWS_SUCCESS', 'NVIM_SMOKE_SUCCESS')) {
    $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
$env:NVIM_WINDOWS_REPO = $repo
$env:NVIM_WINDOWS_SHELL = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell' } else { 'pwsh' }
$script:count = 0

function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Write-Text([string]$Path, [string]$Text) {
    $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Get-Tree([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { return 'absent' }
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return 'link:' + $item.Target }
    if (-not $item.PSIsContainer) { return 'file:' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path)) }
    $entries = @(Get-ChildItem -LiteralPath $Path -Force | Sort-Object Name | ForEach-Object {
        $_.Name + ':' + (Get-Tree $_.FullName)
    })
    return 'dir:{' + ($entries -join '|') + '}'
}

function New-Fixture {
    $base = Join-Path $temp ([guid]::NewGuid().ToString('N'))
    $source = Join-Path $base ('checkout [space] ' + [char]0x6D4B)
    $target = Join-Path $base ('config [space] ' + [char]0x8BD5 + '\nvim')
    $null = [IO.Directory]::CreateDirectory($source)
    Copy-Item -LiteralPath (Join-Path $repo 'install.ps1') -Destination (Join-Path $source 'install.ps1')
    foreach ($name in @('init.lua', 'lua\plugins\init.lua', 'lua\config\settings.lua', 'lua\config\plugins\example.lua', 'UltiSnips\all.snippets')) {
        Write-Text (Join-Path $source $name) ('public:' + $name)
    }
    Write-Text (Join-Path $source 'lua\config\private.lua') 'SOURCE PRIVATE MUST NOT COPY'
    Write-Text (Join-Path $source 'lua\config\private_config.lua') 'SOURCE OVERRIDE MUST NOT COPY'
    Write-Text (Join-Path $source 'README.md') 'not runtime'
    return @{ Source = $source; Target = $target; Version = 'NVIM v0.12.5'; Missing = ''; FailActivation = $false; Base = $base }
}

function Invoke-Installer($Fixture, [bool]$Success = $true, [switch]$InvalidArgument, [string]$Expected = '') {
    if (-not $Success -and -not $Expected) { throw 'Refusal tests must specify the expected error.' }
    $caught = $null
    try {
        & {
            param($fixture, $invalidArgument)
            function Get-Command {
                param([string]$Name, $ErrorAction)
                if ($Name -eq $fixture.Missing) { return $null }
                if ($Name -in @('nvim', 'git')) { return [pscustomobject]@{ Name = $Name; Source = $Name } }
                return $null
            }
            function nvim {
                $global:LASTEXITCODE = 0
                if ($args -contains '--version') { return $fixture.Version }
                return $fixture.Target
            }
            function Move-Item {
                [CmdletBinding()]
                param([string]$LiteralPath, [string]$Path, [string]$Destination, [switch]$Force)
                $origin = if ($LiteralPath) { $LiteralPath } else { $Path }
                if ($fixture.FailActivation -and $Destination -eq $fixture.Target -and $origin -match '\.stage\.') {
                    throw 'Injected activation failure'
                }
                Microsoft.PowerShell.Management\Move-Item -LiteralPath $origin -Destination $Destination -Force:$Force
            }
            if ($invalidArgument) {
                & (Join-Path $fixture.Source 'install.ps1') -NotAnOption
            } else {
                & (Join-Path $fixture.Source 'install.ps1') -NoDeps
            }
        } $Fixture $InvalidArgument | Out-Host
    } catch { $caught = $_ }
    if ($Success -and $null -ne $caught) { throw $caught }
    if (-not $Success -and $null -eq $caught) { throw 'Installer unexpectedly succeeded' }
    if ($null -ne $caught) {
        Assert-True ($caught.Exception.Message -match $Expected) ('Wrong refusal: ' + $caught.Exception.Message + '; expected ' + $Expected)
        Write-Host ('Expected refusal: ' + $caught.Exception.Message)
    }
}

function Assert-Runtime($Fixture) {
    foreach ($name in @('init.lua', 'lua\plugins\init.lua', 'lua\config\settings.lua', 'lua\config\plugins\example.lua', 'UltiSnips\all.snippets')) {
        $target = Join-Path $Fixture.Target $name
        Assert-True ([IO.File]::Exists($target)) ('missing runtime ' + $name)
        Assert-True ([IO.File]::ReadAllText($target) -eq [IO.File]::ReadAllText((Join-Path $Fixture.Source $name))) ('wrong runtime ' + $name)
    }
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture.Target 'README.md'))) 'README copied'
    foreach ($name in @('private.lua', 'private_config.lua')) {
        $path = Join-Path $Fixture.Target ('lua\config\' + $name)
        if ([IO.File]::Exists($path)) { Assert-True (-not [IO.File]::ReadAllText($path).Contains('SOURCE')) 'source private data copied' }
    }
}

function Get-Backups($Fixture) {
    $parent = Split-Path -Parent $Fixture.Target
    if (Test-Path -LiteralPath $parent) { Get-ChildItem -LiteralPath $parent -Force | Where-Object { $_.Name -like '*.backup.*' } }
}

function Test-Case([string]$Name, [scriptblock]$Body) {
    & $Body
    $script:count++
    Write-Host ('PASS: ' + $Name)
}

function Invoke-Probe([string]$Mode, [switch]$LoadConfig) {
    $env:NVIM_WINDOWS_TEST_MODE = $Mode
    $env:NVIM_WINDOWS_SUCCESS = Join-Path $temp ($Mode + '.passed')
    $env:NVIM_SMOKE_SUCCESS = Join-Path $temp ($Mode + '.guard')
    $arguments = @('--headless', '-i', 'NONE', '-n')
    if (-not $LoadConfig) { $arguments += @('-u', 'NONE', '--noplugin') }
    $arguments += @('--cmd', "lua dofile(vim.env.NVIM_WINDOWS_REPO .. '/scripts/smoke-guard.lua')", '-c', "lua dofile(vim.env.NVIM_WINDOWS_REPO .. '/scripts/windows-regression.lua')")
    $preference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $nvim @arguments 2>&1)
        $status = $LASTEXITCODE
    } finally { $ErrorActionPreference = $preference }
    $text = $output -join "`n"
    Write-Host $text
    Assert-True ($status -eq 0 -and [IO.File]::Exists($env:NVIM_WINDOWS_SUCCESS) -and [IO.File]::Exists($env:NVIM_SMOKE_SUCCESS)) ($Mode + ' probe failed')
    Assert-True (-not ($text -match '(?m)^Error\b|\bE\d{2,}:')) ($Mode + ' emitted an error')
}

try {
    if ($Integration) {
        Invoke-Probe 'integration' -LoadConfig
        Write-Host 'PASS: installed Windows configuration'
    } else {
        foreach ($name in @('XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME')) {
            [Environment]::SetEnvironmentVariable($name, (Join-Path $temp $name), 'Process')
        }
        $env:NVIM_APPNAME = 'test-app'
        $env:NVIM_LOG_FILE = Join-Path $temp 'nvim.log'
        Test-Case 'clean install, private exclusions, unchanged rerun' {
            $f = New-Fixture
            Invoke-Installer $f
            Assert-Runtime $f
            $before = Get-Tree $f.Target
            Invoke-Installer $f
            Assert-True ((Get-Tree $f.Target) -eq $before) 'rerun changed files'
            Assert-True (@(Get-Backups $f).Count -eq 0) 'unchanged rerun created backup'
        }
        Test-Case 'private and unmanaged files preserved; independent backup' {
            $f = New-Fixture
            Write-Text (Join-Path $f.Target 'init.lua') 'old init'
            Write-Text (Join-Path $f.Target 'keep.txt') 'unmanaged'
            Write-Text (Join-Path $f.Target 'lua\config\private.lua') 'return { old = true }'
            Write-Text (Join-Path $f.Target 'lua\config\private_config.lua') 'local personal = true'
            Write-Text (Join-Path $f.Target 'UltiSnips\old.snippets') 'stale managed'
            $before = Get-Tree $f.Target
            Invoke-Installer $f
            Assert-Runtime $f
            Assert-True ([IO.File]::ReadAllText((Join-Path $f.Target 'keep.txt')) -eq 'unmanaged') 'lost unmanaged'
            Assert-True ([IO.File]::ReadAllText((Join-Path $f.Target 'lua\config\private_config.lua')) -eq 'local personal = true') 'lost private override'
            Assert-True ([IO.File]::ReadAllText((Join-Path $f.Target 'lua\config\private.lua')) -eq 'return { old = true }') 'lost private specs'
            Assert-True (-not [IO.File]::Exists((Join-Path $f.Target 'UltiSnips\old.snippets'))) 'stale managed file kept'
            $backups = @(Get-Backups $f)
            Assert-True ($backups.Count -eq 1) 'expected one backup'
            Assert-True ((Get-Tree $backups[0].FullName) -eq $before) 'backup differs'
            Write-Text (Join-Path $f.Source 'init.lua') 'changed source'
            Write-Text (Join-Path $f.Target 'lua\config\private.lua') 'changed private'
            Assert-True ((Get-Tree $backups[0].FullName) -eq $before) 'backup not independent'
        }
        Test-Case 'version and executable gates preserve config' {
            foreach ($missing in @('nvim', 'git', '')) {
                $f = New-Fixture
                $f.Missing = $missing
                if ($missing -eq '') { $f.Version = 'NVIM v0.11.9' }
                Write-Text (Join-Path $f.Target 'init.lua') 'original'
                $before = Get-Tree $f.Base
                $expected = if ($missing) { [regex]::Escape($missing + ' was not found on PATH') } else { 'Neovim 0\.12\+ is required; found' }
                Invoke-Installer $f $false -Expected $expected
                Assert-True ((Get-Tree $f.Base) -eq $before) 'failed gate changed files'
            }
            foreach ($version in @('garbage', 'NVIM v0.9.5')) {
                $f = New-Fixture
                $f.Version = $version
                $expected = if ($version -eq 'garbage') { 'cannot verify the Neovim version' } else { 'Neovim 0\.12\+ is required; found' }
                Invoke-Installer $f $false -Expected $expected
                Assert-True (-not (Test-Path -LiteralPath $f.Target)) 'invalid version created config'
            }
        }
        Test-Case 'refusal harness rejects unrelated exceptions' {
            $f = New-Fixture
            Write-Text (Join-Path $f.Source 'install.ps1') "throw 'unrelated fixture failure'"
            $rejected = $false
            try { Invoke-Installer $f $false -Expected 'not a fully qualified Windows path' }
            catch { $rejected = $_.Exception.Message -like 'Wrong refusal:*unrelated fixture failure*' }
            Assert-True $rejected 'refusal harness accepted an unrelated exception'
        }
        Test-Case 'future Neovim accepted' {
            $f = New-Fixture
            $f.Version = 'NVIM v1.0.0'
            Invoke-Installer $f
            Assert-Runtime $f
        }
        Test-Case 'same checkout no-op and overlap refusal' {
            $f = New-Fixture
            $f.Target = $f.Source
            $before = Get-Tree $f.Source
            Invoke-Installer $f
            Assert-True ((Get-Tree $f.Source) -eq $before) 'same checkout mutated'
            $f.Target = Join-Path $f.Source 'nested'
            Invoke-Installer $f $false -Expected 'Refusing to install: the configuration directory .* lives inside the checkout'
            $f.Target = $f.Base
            Invoke-Installer $f $false -Expected 'Refusing to install: the checkout .* lives inside the configuration directory'
            Assert-True ((Get-Tree $f.Source) -eq $before) 'overlap mutated source'
        }
        Test-Case 'invalid paths and unknown arguments refused' {
            foreach ($path in @('C:relative', '\rooted', 'relative')) {
                $f = New-Fixture
                $f.Target = $path
                Invoke-Installer $f $false -Expected 'not a fully qualified Windows path'
            }
            $f = New-Fixture
            Invoke-Installer $f $false -InvalidArgument -Expected "parameter.*NotAnOption"
            Assert-True (-not (Test-Path -LiteralPath $f.Target)) 'unknown argument created config'
        }
        Test-Case 'regular file containers safely replaced' {
            foreach ($name in @('', 'lua', 'lua\config')) {
                $f = New-Fixture
                $path = if ($name) { Join-Path $f.Target $name } else { $f.Target }
                Write-Text $path 'old container'
                $before = Get-Tree $f.Target
                Invoke-Installer $f
                Assert-Runtime $f
                $backups = @(Get-Backups $f)
                Assert-True ($backups.Count -eq 1 -and (Get-Tree $backups[0].FullName) -eq $before) 'container backup lost'
            }
        }
        Test-Case 'junctions refused without touching external files' {
            foreach ($where in @('target', 'ancestor', 'descendant', 'source')) {
                $f = New-Fixture
                $outside = Join-Path $f.Base 'outside'
                Write-Text (Join-Path $outside 'sentinel.txt') 'external'
                $junction = switch ($where) {
                    'target' { $f.Target }
                    'ancestor' { Split-Path -Parent $f.Target }
                    'descendant' { Join-Path $f.Target 'linked' }
                    'source' { Join-Path $f.Source 'UltiSnips\linked' }
                }
                $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $junction))
                $null = New-Item -ItemType Junction -Path $junction -Target $outside
                try {
                    $before = Get-Tree $f.Base
                    $expected = switch ($where) {
                        'target' { 'Refusing to replace a link or junction' }
                        'ancestor' { 'ancestor is a link or junction' }
                        'descendant' { 'configuration directory because it contains a link or junction' }
                        'source' { 'checkout because it contains a link or junction' }
                    }
                    Invoke-Installer $f $false -Expected $expected
                    Assert-True ((Get-Tree $f.Base) -eq $before) 'junction refusal changed files'
                } finally { [IO.Directory]::Delete($junction) }
            }
        }
        Test-Case 'linked source containers refused before private data is read' {
            foreach ($container in @('lua', 'lua\config')) {
                $f = New-Fixture
                $path = Join-Path $f.Source $container
                $outside = Join-Path $f.Base 'source-container'
                Move-Item -LiteralPath $path -Destination $outside
                $null = New-Item -ItemType Junction -Path $path -Target $outside
                try {
                    $before = Get-Tree $f.Base
                    Invoke-Installer $f $false -Expected 'Expected an ordinary checkout directory'
                    Assert-True ((Get-Tree $f.Base) -eq $before) 'linked source changed files'
                } finally { [IO.Directory]::Delete($path) }
            }
        }
        Test-Case 'activation failure restores original configuration' {
            $f = New-Fixture
            Write-Text (Join-Path $f.Target 'init.lua') 'recover me'
            $before = Get-Tree $f.Target
            $f.FailActivation = $true
            Invoke-Installer $f $false -Expected 'Activation failed.*Injected activation failure.*previous configuration was restored'
            Assert-True ((Get-Tree $f.Target) -eq $before) 'rollback did not restore original'
            Assert-True (@(Get-ChildItem -LiteralPath (Split-Path -Parent $f.Target) -Force | Where-Object { $_.Name -like '*.stage.*' }).Count -eq 0) 'stage leaked'
        }
        Test-Case 'actual Neovim config path respects XDG and NVIM_APPNAME' {
            $f = New-Fixture
            $env:XDG_CONFIG_HOME = Join-Path $f.Base ('actual [config] ' + [char]0x6D4B)
            $env:NVIM_APPNAME = 'custom-app'
            & (Join-Path $f.Source 'install.ps1') -NoDeps
            $f.Target = Join-Path $env:XDG_CONFIG_HOME $env:NVIM_APPNAME
            Assert-Runtime $f
        }
        Invoke-Probe 'unit'
        Invoke-Probe 'shell'
        Write-Host ('PASS: ' + $script:count + ' installer cases and Windows Lua/shell probes')
    }
} finally {
    foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    Remove-Item -LiteralPath $temp -Recurse -Force
}
