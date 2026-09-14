#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$NoDeps,
    [switch]$Help
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:PrivateFileNames = @('private.lua', 'private_config.lua')
$script:MaxTreeDepth = 64
$script:PrivateSpecContent = "-- Optional personal plugin specs. This file is never overwritten.`nreturn {}`n"

function Show-Usage {
    Write-Output 'Usage: install.ps1 [-NoDeps] [-Help]'
    Write-Output ''
    Write-Output '  -NoDeps   Skip the optional dependency report.'
    Write-Output '  -Help     Print this message and exit.'
    Write-Output ''
    Write-Output 'Installs this checkout into the Neovim configuration directory reported by'
    Write-Output "nvim (vim.fn.stdpath('config')) using ordinary file copies. Requires Neovim 0.12+"
    Write-Output 'and git on PATH. Nothing is installed, elevated or linked.'
}

function Test-CommandAvailable {
    param([string]$Name)

    $command = $null
    try {
        $command = Get-Command -Name $Name
    } catch {
        $command = $null
    }
    return ($null -ne $command)
}

function Get-LastNativeExitCode {
    $variable = Get-Variable -Name 'LASTEXITCODE' -ErrorAction SilentlyContinue
    if ($null -eq $variable -or $null -eq $variable.Value) {
        throw 'Neovim did not return a native process exit code.'
    }
    return [int]$variable.Value
}

function Invoke-Nvim {
    param([string[]]$Arguments)

    $output = $null
    $code = 0
    $preference = $ErrorActionPreference
    try {
        # PowerShell 5.1 treats redirected native stderr as errors; check the exit code explicitly.
        $ErrorActionPreference = 'Continue'
        $output = & nvim @Arguments 2>$null
        $code = Get-LastNativeExitCode
    } finally {
        $ErrorActionPreference = $preference
    }
    return [pscustomobject]@{
        Lines    = @($output)
        ExitCode = $code
    }
}

function Test-FullyQualifiedPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }
    if ($Path.IndexOfAny([char[]]@('*', '?', '"', '<', '>', '|')) -ge 0) {
        return $false
    }
    foreach ($character in $Path.ToCharArray()) {
        if ([int]$character -lt 32) {
            return $false
        }
    }
    if ($Path -match '^[A-Za-z]:[\\/]') {
        return $true
    }
    if ($Path -match '^[\\/]{2}[^\\/:]+[\\/][^\\/:]+([\\/]|$)') {
        return $true
    }
    return $false
}

function Confirm-FullyQualifiedPath {
    param([string]$Path, [string]$Label)

    if (-not (Test-FullyQualifiedPath -Path $Path)) {
        throw "$Label is not a fully qualified Windows path: '$Path'. Use a drive-absolute path (C:\...) or a UNC path (\\server\share\...)."
    }
}

function Get-NormalizedPath {
    param([string]$Path)

    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.Length -gt 3) {
        $trimmed = $full.TrimEnd('\', '/')
        if ($trimmed.Length -gt 0) {
            $full = $trimmed
        }
    }
    return $full
}

function Test-SamePath {
    param([string]$Left, [string]$Right)

    return [string]::Equals($Left, $Right, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-PathContainsPath {
    param([string]$Ancestor, [string]$Descendant)

    if (Test-SamePath -Left $Ancestor -Right $Descendant) {
        return $false
    }
    $prefix = $Ancestor.TrimEnd('\') + '\'
    return $Descendant.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-EntryInfo {
    param([string]$Path)

    $full = Get-NormalizedPath -Path $Path
    $parent = [System.IO.Path]::GetDirectoryName($full)
    $name = [System.IO.Path]::GetFileName($full)
    if ([string]::IsNullOrEmpty($parent) -or [string]::IsNullOrEmpty($name)) {
        $root = New-Object System.IO.DirectoryInfo $full
        return [pscustomobject]@{
            Path           = $full
            Exists         = $root.Exists
            IsDirectory    = $true
            IsReparsePoint = $false
        }
    }
    $missing = [pscustomobject]@{
        Path           = $full
        Exists         = $false
        IsDirectory    = $false
        IsReparsePoint = $false
    }
    $parentInfo = New-Object System.IO.DirectoryInfo $parent
    if (-not $parentInfo.Exists) {
        return $missing
    }
    # Enumerating the parent reports the link itself, so hidden and dangling links stay visible.
    foreach ($entry in $parentInfo.EnumerateFileSystemInfos($name)) {
        if (-not [string]::Equals($entry.Name, $name, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        $attributes = $entry.Attributes
        return [pscustomobject]@{
            Path           = $full
            Exists         = $true
            IsDirectory    = (($attributes -band [System.IO.FileAttributes]::Directory) -ne 0)
            IsReparsePoint = (($attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
        }
    }
    return $missing
}

function Confirm-NoReparseAncestor {
    param([string]$Path, [string]$Label)

    $current = [System.IO.Path]::GetDirectoryName((Get-NormalizedPath -Path $Path))
    while (-not [string]::IsNullOrEmpty($current)) {
        $info = Get-EntryInfo -Path $current
        if ($info.Exists -and $info.IsReparsePoint) {
            throw "Refusing to touch the $Label because an ancestor is a link or junction: $($info.Path)."
        }
        $next = [System.IO.Path]::GetDirectoryName($current)
        if ([string]::IsNullOrEmpty($next) -or (Test-SamePath -Left $next -Right $current)) {
            break
        }
        $current = $next
    }
}

function Confirm-NoReparseTree {
    param([string]$Path, [string]$Label, [int]$Depth = 0)

    if ($Depth -gt $script:MaxTreeDepth) {
        throw "The $Label exceeds $($script:MaxTreeDepth) directory levels: $Path."
    }
    $info = Get-EntryInfo -Path $Path
    if (-not $info.Exists) {
        return
    }
    if ($info.IsReparsePoint) {
        throw "Refusing to touch the $Label because it is a link or junction: $($info.Path)."
    }
    if (-not $info.IsDirectory) {
        return
    }
    $directory = New-Object System.IO.DirectoryInfo $info.Path
    foreach ($entry in $directory.EnumerateFileSystemInfos()) {
        $attributes = $entry.Attributes
        if (($attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing to touch the $Label because it contains a link or junction: $($entry.FullName)."
        }
        if (($attributes -band [System.IO.FileAttributes]::Directory) -ne 0) {
            Confirm-NoReparseTree -Path $entry.FullName -Label $Label -Depth ($Depth + 1)
        }
    }
}

function Get-ManagedItems {
    param([string]$SourceRoot)

    $items = New-Object System.Collections.ArrayList
    [void]$items.Add([pscustomobject]@{ Relative = 'init.lua'; Kind = 'File' })
    [void]$items.Add([pscustomobject]@{ Relative = 'UltiSnips'; Kind = 'Directory' })
    [void]$items.Add([pscustomobject]@{ Relative = 'lua\plugins'; Kind = 'Directory' })
    [void]$items.Add([pscustomobject]@{ Relative = 'lua\config\plugins'; Kind = 'Directory' })

    $configDirectory = New-Object System.IO.DirectoryInfo ([System.IO.Path]::Combine($SourceRoot, 'lua\config'))
    if (-not $configDirectory.Exists) {
        throw "The checkout is missing lua\config: $($configDirectory.FullName)."
    }
    $names = New-Object System.Collections.ArrayList
    foreach ($entry in $configDirectory.EnumerateFileSystemInfos('*.lua')) {
        if (($entry.Attributes -band [System.IO.FileAttributes]::Directory) -ne 0) {
            continue
        }
        if (-not $entry.Name.EndsWith('.lua', [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        if ($script:PrivateFileNames -contains $entry.Name.ToLowerInvariant()) {
            continue
        }
        [void]$names.Add($entry.Name)
    }
    foreach ($name in ($names | Sort-Object)) {
        [void]$items.Add([pscustomobject]@{ Relative = "lua\config\$name"; Kind = 'File' })
    }
    return $items.ToArray()
}

function Confirm-SourceLayout {
    param([string]$SourceRoot, $ManagedItems)

    foreach ($item in $ManagedItems) {
        $path = [System.IO.Path]::Combine($SourceRoot, $item.Relative)
        $info = Get-EntryInfo -Path $path
        if (-not $info.Exists) {
            throw "The checkout is missing a managed item: $path."
        }
        if ($info.IsReparsePoint) {
            throw "Refusing to install from a link or junction in the checkout: $path."
        }
        if ($item.Kind -eq 'Directory' -and -not $info.IsDirectory) {
            throw "Expected a directory in the checkout but found a file: $path."
        }
        if ($item.Kind -eq 'File' -and $info.IsDirectory) {
            throw "Expected a file in the checkout but found a directory: $path."
        }
        if ($item.Kind -eq 'Directory') {
            Confirm-NoReparseTree -Path $path -Label 'checkout'
        }
    }
}

function Get-FileSha256 {
    param([string]$Path)

    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            return [System.BitConverter]::ToString($algorithm.ComputeHash($stream))
        } finally {
            $stream.Dispose()
        }
    } finally {
        $algorithm.Dispose()
    }
}

function Add-TreeSnapshotEntry {
    param([string]$Directory, [string]$Prefix, [int]$Depth, $Map)

    if ($Depth -gt $script:MaxTreeDepth) {
        throw "Directory tree exceeds $($script:MaxTreeDepth) levels: $Directory."
    }
    $info = New-Object System.IO.DirectoryInfo $Directory
    foreach ($entry in $info.EnumerateFileSystemInfos()) {
        $relative = $entry.Name
        if ($Prefix -ne '') {
            $relative = $Prefix + '\' + $entry.Name
        }
        $attributes = $entry.Attributes
        if (($attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing to compare a link or junction: $($entry.FullName)."
        }
        if (($attributes -band [System.IO.FileAttributes]::Directory) -ne 0) {
            $Map[$relative] = 'D'
            Add-TreeSnapshotEntry -Directory $entry.FullName -Prefix $relative -Depth ($Depth + 1) -Map $Map
        } else {
            $Map[$relative] = 'F:' + $entry.Length + ':' + (Get-FileSha256 -Path $entry.FullName)
        }
    }
}

function Get-TreeSnapshot {
    param([string]$Root)

    $map = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::OrdinalIgnoreCase)
    Add-TreeSnapshotEntry -Directory $Root -Prefix '' -Depth 0 -Map $map
    return $map
}

function Test-TreeEqual {
    param([string]$Left, [string]$Right)

    $leftMap = Get-TreeSnapshot -Root $Left
    $rightMap = Get-TreeSnapshot -Root $Right
    if ($leftMap.Count -ne $rightMap.Count) {
        return $false
    }
    foreach ($key in $leftMap.Keys) {
        if (-not $rightMap.ContainsKey($key)) {
            return $false
        }
        if ($leftMap[$key] -ne $rightMap[$key]) {
            return $false
        }
    }
    return $true
}

function Copy-TreeStrict {
    param([string]$Source, [string]$Destination, [int]$Depth = 0)

    if ($Depth -gt $script:MaxTreeDepth) {
        throw "Directory tree exceeds $($script:MaxTreeDepth) levels: $Source."
    }
    $info = Get-EntryInfo -Path $Source
    if (-not $info.Exists) {
        throw "Cannot copy a missing path: $Source."
    }
    if ($info.IsReparsePoint) {
        throw "Refusing to copy through a link or junction: $Source."
    }
    if ($info.IsDirectory) {
        [void][System.IO.Directory]::CreateDirectory($Destination)
        $directory = New-Object System.IO.DirectoryInfo $info.Path
        foreach ($entry in $directory.EnumerateFileSystemInfos()) {
            Copy-TreeStrict -Source $entry.FullName -Destination ([System.IO.Path]::Combine($Destination, $entry.Name)) -Depth ($Depth + 1)
        }
    } else {
        Copy-Item -LiteralPath $info.Path -Destination $Destination -Force
    }
}

function Copy-TreeChildren {
    param([string]$Source, [string]$Destination)

    $directory = New-Object System.IO.DirectoryInfo $Source
    foreach ($entry in $directory.EnumerateFileSystemInfos()) {
        Copy-TreeStrict -Source $entry.FullName -Destination ([System.IO.Path]::Combine($Destination, $entry.Name)) -Depth 1
    }
}

function Initialize-StageDirectory {
    param([string]$Path)

    $info = Get-EntryInfo -Path $Path
    if ($info.Exists -and -not $info.IsDirectory) {
        Remove-Item -LiteralPath $info.Path -Force
    }
    [void][System.IO.Directory]::CreateDirectory($Path)
}

function Remove-OwnedPath {
    param([string]$Path)

    if ([string]::IsNullOrEmpty($Path)) {
        return
    }
    $info = Get-EntryInfo -Path $Path
    if (-not $info.Exists) {
        return
    }
    if ($info.IsDirectory) {
        Remove-Item -LiteralPath $info.Path -Recurse -Force
    } else {
        Remove-Item -LiteralPath $info.Path -Force
    }
}

function Write-DependencyReport {
    param([string]$ConfigRoot)

    $optional = @(
        [pscustomobject]@{ Names = @('rg'); Label = 'ripgrep (rg)'; Hint = 'winget install BurntSushi.ripgrep.MSVC' },
        [pscustomobject]@{ Names = @('ag'); Label = 'the_silver_searcher (ag)'; Hint = 'scoop install ag' },
        [pscustomobject]@{ Names = @('fzf'); Label = 'fzf'; Hint = 'winget install junegunn.fzf' },
        [pscustomobject]@{ Names = @('ctags'); Label = 'universal-ctags (ctags)'; Hint = 'winget install UniversalCtags.Ctags' },
        [pscustomobject]@{ Names = @('python3', 'python', 'py'); Label = 'Python'; Hint = 'winget install Python.Python.3.12' },
        [pscustomobject]@{ Names = @('cl', 'clang', 'gcc', 'cc'); Label = 'C compiler (cl, clang or gcc) for Treesitter parsers'; Hint = 'install Visual Studio Build Tools or LLVM' },
        [pscustomobject]@{ Names = @('tree-sitter'); Label = 'tree-sitter CLI 0.26.1+'; Hint = 'install from your package manager, not npm' },
        [pscustomobject]@{ Names = @('tar'); Label = 'tar'; Hint = 'ships with Windows 10 1803 and later' },
        [pscustomobject]@{ Names = @('curl'); Label = 'curl'; Hint = 'ships with Windows 10 1803 and later' }
    )
    $missing = New-Object System.Collections.ArrayList
    foreach ($dependency in $optional) {
        $found = $false
        foreach ($name in $dependency.Names) {
            if (Test-CommandAvailable -Name $name) {
                $found = $true
                break
            }
        }
        if (-not $found) {
            [void]$missing.Add($dependency)
        }
    }
    Write-Output ''
    if ($missing.Count -eq 0) {
        Write-Output 'Optional dependencies: all found on PATH. Nothing was installed by this script.'
    } else {
        Write-Output 'Optional dependencies missing from PATH (nothing is installed for you):'
        foreach ($dependency in $missing) {
            Write-Output "  - $($dependency.Label): $($dependency.Hint)"
        }
    }
    Write-Output 'A Python executable on PATH does not prove the Neovim Python provider works;'
    Write-Output 'run :checkhealth vim.provider in Neovim to verify pynvim.'
    Write-Output "Re-run with -NoDeps to skip this report. Configuration: $ConfigRoot"
}

if ($Help) {
    Show-Usage
    return
}

if ($env:OS -ne 'Windows_NT') {
    throw 'install.ps1 targets native Windows only; use install.sh on macOS, Linux or WSL.'
}

$sourceRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($sourceRoot)) {
    throw 'Cannot determine the checkout directory; run install.ps1 as a file on disk.'
}
Confirm-FullyQualifiedPath -Path $sourceRoot -Label 'The checkout path'
$sourceRoot = Get-NormalizedPath -Path $sourceRoot
$sourceInfo = Get-EntryInfo -Path $sourceRoot
if (-not $sourceInfo.Exists -or -not $sourceInfo.IsDirectory) {
    throw "The checkout directory is missing: $sourceRoot."
}
if ($sourceInfo.IsReparsePoint) {
    throw "Refusing to install from a link or junction: $sourceRoot."
}
Confirm-NoReparseAncestor -Path $sourceRoot -Label 'checkout'
foreach ($container in @('lua', 'lua\config')) {
    $path = [IO.Path]::Combine($sourceRoot, $container)
    $info = Get-EntryInfo -Path $path
    if (-not $info.Exists -or -not $info.IsDirectory -or $info.IsReparsePoint) {
        throw "Expected an ordinary checkout directory: $path."
    }
}

foreach ($tool in @('git', 'nvim')) {
    if (-not (Test-CommandAvailable -Name $tool)) {
        throw "Error: $tool was not found on PATH. Install $tool before running install.ps1."
    }
}

$probeLog = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "nvim-install-probe-$([guid]::NewGuid().ToString('N')).log")
$previousLogFile = [Environment]::GetEnvironmentVariable('NVIM_LOG_FILE', 'Process')
$previousConsoleEncoding = $null
$encodingChanged = $false
$configRoot = ''
try {
    [Environment]::SetEnvironmentVariable('NVIM_LOG_FILE', $probeLog, 'Process')
    # Neovim prints UTF-8 paths; PowerShell 5.1 otherwise decodes them with the OEM code page.
    try {
        $previousConsoleEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
        $encodingChanged = $true
    } catch {
        $encodingChanged = $false
    }

    $version = Invoke-Nvim -Arguments @('--version')
    if ($version.ExitCode -ne 0) {
        throw "Error: 'nvim --version' failed with exit code $($version.ExitCode); Neovim 0.12+ is required."
    }
    $versionLines = @($version.Lines)
    $firstLine = ''
    if ($versionLines.Count -gt 0 -and $null -ne $versionLines[0]) {
        $firstLine = [string]$versionLines[0]
    }
    if ($firstLine -notmatch '^NVIM v([0-9]+)\.([0-9]+)\.([0-9]+)') {
        throw 'Error: cannot verify the Neovim version; Neovim 0.12+ is required.'
    }
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    if ($major -eq 0 -and $minor -lt 12) {
        throw "Error: Neovim 0.12+ is required; found $firstLine."
    }

    $probe = Invoke-Nvim -Arguments @(
        '--headless', '-u', 'NONE', '-i', 'NONE', '-n', '--noplugin',
        '-c', "lua io.stdout:write(vim.fn.stdpath('config'))",
        '-c', 'qa'
    )
    if ($probe.ExitCode -ne 0) {
        throw "Error: Neovim could not report its configuration directory (exit code $($probe.ExitCode))."
    }
    $pathLines = @($probe.Lines)
    if ($pathLines.Count -ne 1) { throw 'Neovim must report exactly one configuration path.' }
    $configRoot = [string]$pathLines[0]
} finally {
    [Environment]::SetEnvironmentVariable('NVIM_LOG_FILE', $previousLogFile, 'Process')
    if ($encodingChanged -and $null -ne $previousConsoleEncoding) {
        try {
            [Console]::OutputEncoding = $previousConsoleEncoding
        } catch {
            Write-Output 'Note: could not restore the previous console output encoding.'
        }
    }
    try {
        Remove-OwnedPath -Path $probeLog
    } catch {
        Write-Output "Note: could not remove the temporary probe log: $probeLog"
    }
}

if ([string]::IsNullOrWhiteSpace($configRoot)) {
    throw 'Error: Neovim reported an empty configuration directory.'
}
Confirm-FullyQualifiedPath -Path $configRoot -Label 'The Neovim configuration path'
$targetRoot = Get-NormalizedPath -Path $configRoot
$targetInfo = Get-EntryInfo -Path $targetRoot

if (Test-SamePath -Left $targetRoot -Right $sourceRoot) {
    if ($targetInfo.Exists -and $targetInfo.IsDirectory -and -not $targetInfo.IsReparsePoint) {
        Write-Output "This checkout is already the Neovim configuration: $targetRoot"
        Write-Output 'Nothing to copy, no backup created.'
        return
    }
    throw "The configuration path equals the checkout path but is not an ordinary directory: $targetRoot."
}
if (Test-PathContainsPath -Ancestor $targetRoot -Descendant $sourceRoot) {
    throw "Refusing to install: the checkout ($sourceRoot) lives inside the configuration directory ($targetRoot)."
}
if (Test-PathContainsPath -Ancestor $sourceRoot -Descendant $targetRoot) {
    throw "Refusing to install: the configuration directory ($targetRoot) lives inside the checkout ($sourceRoot)."
}

Confirm-NoReparseAncestor -Path $targetRoot -Label 'configuration directory'
if ($targetInfo.Exists -and $targetInfo.IsReparsePoint) {
    throw "Refusing to replace a link or junction: $targetRoot. Remove it yourself and re-run install.ps1."
}
if ($targetInfo.Exists -and $targetInfo.IsDirectory) {
    Confirm-NoReparseTree -Path $targetRoot -Label 'configuration directory'
}

$managedItems = Get-ManagedItems -SourceRoot $sourceRoot
Confirm-SourceLayout -SourceRoot $sourceRoot -ManagedItems $managedItems

$targetParent = [System.IO.Path]::GetDirectoryName($targetRoot)
$targetName = [System.IO.Path]::GetFileName($targetRoot)
if ([string]::IsNullOrEmpty($targetParent) -or [string]::IsNullOrEmpty($targetName)) {
    throw "Refusing to install into a filesystem root: $targetRoot."
}

# Everything below writes only to freshly created sibling paths until the final move.
[void][System.IO.Directory]::CreateDirectory($targetParent)
$stageRoot = [System.IO.Path]::Combine($targetParent, "$targetName.stage.$([guid]::NewGuid().ToString('N'))")
if ((Get-EntryInfo -Path $stageRoot).Exists) {
    throw "The staging directory already exists: $stageRoot."
}

$stageOwned = $false
$backupRoot = $null
$identical = $false
try {
    [void][System.IO.Directory]::CreateDirectory($stageRoot)
    $stageOwned = $true

    if ($targetInfo.Exists -and $targetInfo.IsDirectory) {
        Copy-TreeChildren -Source $targetRoot -Destination $stageRoot
    }

    foreach ($relative in @('lua', 'lua\config')) {
        Initialize-StageDirectory -Path ([System.IO.Path]::Combine($stageRoot, $relative))
    }

    foreach ($item in $managedItems) {
        $stagePath = [System.IO.Path]::Combine($stageRoot, $item.Relative)
        Initialize-StageDirectory -Path ([System.IO.Path]::GetDirectoryName($stagePath))
        Remove-OwnedPath -Path $stagePath
        Copy-TreeStrict -Source ([System.IO.Path]::Combine($sourceRoot, $item.Relative)) -Destination $stagePath
    }

    $stagedPrivate = [System.IO.Path]::Combine($stageRoot, 'lua\config\private.lua')
    if (-not (Get-EntryInfo -Path $stagedPrivate).Exists) {
        [System.IO.File]::WriteAllText($stagedPrivate, $script:PrivateSpecContent, (New-Object System.Text.UTF8Encoding $false))
    }

    if ($targetInfo.Exists -and $targetInfo.IsDirectory) {
        $identical = Test-TreeEqual -Left $targetRoot -Right $stageRoot
    }

    if (-not $identical) {
        if ($targetInfo.Exists) {
            $candidate = [System.IO.Path]::Combine($targetParent, "$targetName.backup.$([guid]::NewGuid().ToString('N'))")
            if ((Get-EntryInfo -Path $candidate).Exists) {
                throw "The backup path already exists: $candidate."
            }
            Move-Item -LiteralPath $targetRoot -Destination $candidate
            $backupRoot = $candidate
        }
        try {
            Move-Item -LiteralPath $stageRoot -Destination $targetRoot
            $stageOwned = $false
        } catch {
            $activationError = $_
            $restored = $false
            if ($null -ne $backupRoot) {
                try {
                    Move-Item -LiteralPath $backupRoot -Destination $targetRoot
                    $restored = $true
                } catch {
                    $restored = $false
                }
            }
            $detail = "Activation failed for $targetRoot : $($activationError.Exception.Message)"
            if ($null -eq $backupRoot) {
                throw "$detail No previous configuration existed, so nothing was lost."
            }
            if ($restored) {
                throw "$detail The previous configuration was restored from the backup $backupRoot to $targetRoot."
            }
            throw "$detail The previous configuration is intact and NOT deleted at $backupRoot; move it back to $targetRoot yourself."
        }
    }
} finally {
    if ($stageOwned) {
        try {
            Remove-OwnedPath -Path $stageRoot
        } catch {
            Write-Output "Note: could not remove the staging directory: $stageRoot"
        }
    }
}

if ($identical) {
    Write-Output "Configuration already up to date: $targetRoot"
    Write-Output 'No files were changed and no backup was created.'
    if (-not $NoDeps) {
        Write-DependencyReport -ConfigRoot $targetRoot
    }
    return
}

Write-Output "Installation complete: $targetRoot"
if ($null -ne $backupRoot) {
    Write-Output "Previous configuration moved to: $backupRoot"
    Write-Output 'That backup is never deleted by this script; remove it yourself once satisfied.'
} else {
    Write-Output 'No previous configuration existed, so no backup was created.'
}
Write-Output 'Managed files are ordinary copies, not links: re-run install.ps1 after every git pull to update them.'
Write-Output 'Unrelated files in the configuration directory are kept, and lua\config\private.lua and'
Write-Output 'lua\config\private_config.lua are never overwritten.'
Write-Output 'Open nvim to install plugins. Leader key: comma (,).'

if (-not $NoDeps) {
    Write-DependencyReport -ConfigRoot $targetRoot
}
