#requires -Version 5.1
<#
.SYNOPSIS
Collects a shareable, read-only Windows readiness report for Phasmophobia.
.DESCRIPTION
Does not launch the game, install software, change files in the game, or change
Steam, the registry, firewall, antivirus, or network settings. The only file
written is the requested JSON report. No account IDs, host/user names, absolute
installation paths, raw log lines, or network addresses are put in that report.
Existing Unity logs belong to this Windows profile and may describe a different
copy or an earlier run. They do not prove this copy launches or joins a lobby.
.EXAMPLE
powershell.exe -NoProfile -File .\Mac-Setup\Check-Windows.ps1
.EXAMPLE
powershell.exe -NoProfile -File .\Mac-Setup\Check-Windows.ps1 -GamePath 'E:\Games\Phasmophobia' -Detailed
#>
[CmdletBinding()]
param(
    [string]$GamePath,
    [string]$OutputPath,
    [switch]$Detailed,
    [switch]$SkipLogScan,
    [ValidateRange(100, 30000)]
    [int]$LogTailLines = 5000
)

$ErrorActionPreference = 'Stop'
$taskScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($GamePath)) {
    $GamePath = Join-Path (Split-Path -Parent $taskScriptDirectory) 'Phasmophobia'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $taskScriptDirectory 'windows-check.json'
}
$taskFindings = New-Object 'System.Collections.Generic.List[object]'

function Add-Finding {
    param([string]$Code, [string]$Severity, [string]$Message)
    [void]$taskFindings.Add([pscustomobject]@{
        code = $Code
        severity = $Severity
        message = $Message
    })
}

function Get-PeArchitecture {
    param([string]$Path)
    $taskStream = $null
    $taskReader = $null
    try {
        $taskStream = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
        $taskReader = New-Object IO.BinaryReader($taskStream)
        if ($taskStream.Length -lt 64 -or $taskReader.ReadUInt16() -ne 0x5A4D) { return 'NotPE' }
        $taskStream.Position = 0x3C
        $taskOffset = $taskReader.ReadInt32()
        if ($taskOffset -lt 64 -or $taskOffset -gt ($taskStream.Length - 6)) { return 'InvalidPE' }
        $taskStream.Position = $taskOffset
        if ($taskReader.ReadUInt32() -ne 0x4550) { return 'InvalidPE' }
        switch ($taskReader.ReadUInt16()) {
            0x8664 { return 'x64' }
            0x014C { return 'x86' }
            0xAA64 { return 'ARM64' }
            default { return 'Other' }
        }
    } catch {
        return 'Unreadable'
    } finally {
        if ($taskReader) { $taskReader.Dispose() }
        elseif ($taskStream) { $taskStream.Dispose() }
    }
}

function Get-VcRuntime {
    param([string]$Architecture)
    foreach ($taskKey in @(
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\$Architecture",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\$Architecture"
    )) {
        try {
            $taskValue = Get-ItemProperty -LiteralPath $taskKey -ErrorAction Stop
            if ($taskValue.Installed -eq 1) {
                return [pscustomobject]@{ installed = $true; version = [string]$taskValue.Version }
            }
        } catch { }
    }
    return [pscustomobject]@{ installed = $false; version = $null }
}

$taskReport = [ordered]@{
    schemaVersion = 1
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
    purpose = 'Windows readiness observations; launch and multiplayer require a manual test.'
    privacy = 'No account IDs, user/host names, absolute paths, raw log text, or network addresses.'
    currentCopyLaunchTested = $false
    multiplayerTested = $false
}

if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
    Write-Error 'This diagnostic must be run on Windows.' -ErrorAction Continue
    exit 2
}

$taskOs = $null
$taskSystem = $null
$taskGpus = @()
try {
    $taskOs = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $taskSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $taskGpus = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object {
        [pscustomobject]@{ name = $_.Name; driverVersion = $_.DriverVersion }
    })
} catch {
    Add-Finding 'HARDWARE_QUERY_PARTIAL' 'info' 'Some hardware information was unavailable; the remaining checks still ran.'
}
$taskReport.host = [ordered]@{
    windows = if ($taskOs) { $taskOs.Caption } else { 'Windows (edition unavailable)' }
    osBuild = if ($taskOs) { $taskOs.BuildNumber } else { [Environment]::OSVersion.Version.Build }
    is64BitOperatingSystem = [Environment]::Is64BitOperatingSystem
    ramGiB = if ($taskSystem) { [Math]::Round($taskSystem.TotalPhysicalMemory / 1GB, 1) } else { $null }
    gpu = $taskGpus
}
if (-not [Environment]::Is64BitOperatingSystem) {
    Add-Finding 'WINDOWS_32_BIT' 'error' 'The game executable requires a 64-bit operating system.'
}

$taskX64Runtime = Get-VcRuntime 'x64'
$taskX86Runtime = Get-VcRuntime 'x86'
$taskReport.visualCpp2015OrLater = [ordered]@{
    x64 = $taskX64Runtime
    x86 = $taskX86Runtime
}
if (-not $taskX64Runtime.installed) {
    Add-Finding 'VC_X64_NOT_DETECTED' 'warning' 'A system-wide Visual C++ 2015-or-later x64 runtime was not detected. If a runtime DLL error occurs, install the current x64 redistributable from Microsoft.'
}

$taskFiles = @(
    'Phasmophobia.exe',
    'UnityPlayer.dll',
    'GameAssembly.dll',
    'Phasmophobia_Data\globalgamemanagers',
    'Phasmophobia_Data\il2cpp_data\Metadata\global-metadata.dat',
    'Phasmophobia_Data\Plugins\x86_64\steam_api64.dll'
)
$taskFileResults = @()
foreach ($taskRelative in $taskFiles) {
    $taskFilePath = Join-Path $GamePath $taskRelative
    $taskPresent = Test-Path -LiteralPath $taskFilePath -PathType Leaf
    $taskFileResult = [ordered]@{
        relativePath = $taskRelative.Replace('\', '/')
        present = $taskPresent
        bytes = $null
        architecture = $null
    }
    if ($taskPresent) {
        try {
            $taskItem = Get-Item -LiteralPath $taskFilePath -ErrorAction Stop
            $taskFileResult.bytes = $taskItem.Length
            if ($taskItem.Extension -in @('.exe', '.dll')) {
                $taskFileResult.architecture = Get-PeArchitecture $taskFilePath
            }
            if ($Detailed -and $taskRelative -in @('Phasmophobia.exe', 'Phasmophobia_Data\Plugins\x86_64\steam_api64.dll')) {
                $taskFileResult.sha256 = (Get-FileHash -LiteralPath $taskFilePath -Algorithm SHA256).Hash.ToLowerInvariant()
            }
            if ($taskItem.Length -eq 0) {
                Add-Finding 'EMPTY_GAME_FILE' 'error' ("A required file is empty: " + $taskFileResult.relativePath)
            }
            if ($taskFileResult.architecture -in @('NotPE', 'InvalidPE', 'Unreadable')) {
                Add-Finding 'INVALID_GAME_BINARY' 'error' ("A required binary could not be read as a valid PE file: " + $taskFileResult.relativePath)
            }
        } catch {
            Add-Finding 'GAME_FILE_UNREADABLE' 'warning' ("A required file could not be inspected: " + $taskFileResult.relativePath)
        }
    } else {
        Add-Finding 'GAME_FILE_MISSING' 'error' ("A required file was not found: " + $taskFileResult.relativePath)
    }
    $taskFileResults += [pscustomobject]$taskFileResult
}

$taskLauncherPath = Join-Path $GamePath 'Launcher.exe'
$taskCustomFiles = @('Launcher.exe', 'OnlineFix64.dll', 'OnlineFix.ini', 'PhotonBridge.dll', 'winmm.dll') |
    Where-Object { Test-Path -LiteralPath (Join-Path $GamePath $_) -PathType Leaf }
$taskUnityVersion = $null
try {
    $taskUnityVersion = (Get-Item -LiteralPath (Join-Path $GamePath 'UnityPlayer.dll')).VersionInfo.ProductVersion
} catch { }
$taskReport.game = [ordered]@{
    directoryPresent = (Test-Path -LiteralPath $GamePath -PathType Container)
    files = $taskFileResults
    unityEngineVersion = $taskUnityVersion
    gameMenuVersion = 'Not measured; record the version shown in the game menu on each player computer.'
    customLauncherPresent = (Test-Path -LiteralPath $taskLauncherPath -PathType Leaf)
    customLauncherArchitecture = if (Test-Path -LiteralPath $taskLauncherPath -PathType Leaf) { Get-PeArchitecture $taskLauncherPath } else { $null }
    additionalFilesObserved = @($taskCustomFiles)
    hashesRequested = [bool]$Detailed
    hashScope = 'With -Detailed: only the game executable and Steam API DLL. Matching these alone does not establish a matching full game build.'
}
if ('OnlineFix64.dll' -in $taskCustomFiles) {
    Add-Finding 'MODIFIED_MULTIPLAYER_COMPONENTS' 'warning' 'This copy contains OnlineFix components. Compatibility with the official Steam service, other clients, and a Mac compatibility layer has not been established.'
}
if ($taskReport.game.customLauncherArchitecture -eq 'x86') {
    Add-Finding 'MIXED_ARCHITECTURES' 'info' 'The custom launcher is x86 while the game is x64. A Mac compatibility engine would need working 32-bit and 64-bit Windows support.'
    if (-not $taskX86Runtime.installed) {
        Add-Finding 'VC_X86_NOT_DETECTED' 'warning' 'The x86 Visual C++ runtime was not detected; the custom x86 launcher may require it.'
    }
}

$taskSteamRoots = New-Object 'System.Collections.Generic.List[string]'
foreach ($taskSteamKey in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
    try {
        $taskSteamValue = Get-ItemProperty -LiteralPath $taskSteamKey -ErrorAction Stop
        foreach ($taskCandidate in @($taskSteamValue.SteamPath, $taskSteamValue.InstallPath)) {
            if ($taskCandidate -and -not $taskSteamRoots.Contains($taskCandidate)) { [void]$taskSteamRoots.Add($taskCandidate) }
        }
    } catch { }
}
$taskDefaultSteamBase = [Environment]::GetFolderPath('ProgramFilesX86')
if ([string]::IsNullOrWhiteSpace($taskDefaultSteamBase)) { $taskDefaultSteamBase = [Environment]::GetFolderPath('ProgramFiles') }
$taskDefaultSteam = Join-Path $taskDefaultSteamBase 'Steam'
if ((Test-Path -LiteralPath $taskDefaultSteam -PathType Container) -and -not $taskSteamRoots.Contains($taskDefaultSteam)) {
    [void]$taskSteamRoots.Add($taskDefaultSteam)
}
$taskLibraries = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$taskSteamPresent = $false
foreach ($taskSteamRoot in $taskSteamRoots) {
    if (Test-Path -LiteralPath (Join-Path $taskSteamRoot 'steam.exe') -PathType Leaf) { $taskSteamPresent = $true }
    [void]$taskLibraries.Add($taskSteamRoot.Replace('/', '\'))
    try {
        $taskLibraryFile = Join-Path $taskSteamRoot 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $taskLibraryFile -PathType Leaf) {
            foreach ($taskLine in Get-Content -LiteralPath $taskLibraryFile) {
                if ($taskLine -match '"path"\s+"([^"]+)"') { [void]$taskLibraries.Add($Matches[1].Replace('\\', '\')) }
            }
        }
    } catch {
        Add-Finding 'STEAM_LIBRARY_UNREADABLE' 'info' 'A Steam library list could not be read. The installed-game check may be incomplete.'
    }
}
$taskManifests = @()
foreach ($taskLibrary in $taskLibraries) {
    try {
        $taskManifestPath = Join-Path $taskLibrary 'steamapps\appmanifest_739630.acf'
        if (Test-Path -LiteralPath $taskManifestPath -PathType Leaf) {
            $taskManifestText = Get-Content -LiteralPath $taskManifestPath -Raw
            $taskManifests += [pscustomobject]@{
                appId = '739630'
                buildId = [regex]::Match($taskManifestText, '"buildid"\s+"(\d+)"').Groups[1].Value
                stateFlags = [regex]::Match($taskManifestText, '"StateFlags"\s+"(\d+)"').Groups[1].Value
            }
        }
    } catch {
        Add-Finding 'STEAM_MANIFEST_UNREADABLE' 'info' 'A game installation record could not be read.'
    }
}
$taskSteamRunning = @(Get-Process -Name steam -ErrorAction SilentlyContinue).Count -gt 0
$taskReport.steam = [ordered]@{
    executableDetected = $taskSteamPresent
    running = $taskSteamRunning
    configuredLibrariesChecked = $taskLibraries.Count
    gameInstallationRecords = $taskManifests
    accountOwnershipAndAuthentication = 'Not inspected.'
}
if (-not $taskSteamPresent) {
    Add-Finding 'STEAM_NOT_DETECTED' 'warning' 'Steam was not found in standard installation locations. Install or locate the official Steam client before testing Steam multiplayer.'
} elseif (-not $taskSteamRunning) {
    Add-Finding 'STEAM_NOT_RUNNING' 'info' 'Steam is installed but was not running when checked. Start Steam and sign in before a Steam multiplayer test.'
}
if ($taskManifests.Count -eq 0) {
    Add-Finding 'NO_STEAM_GAME_INSTALL_RECORD' 'warning' 'No Phasmophobia installation record was found in the configured Steam libraries. This does not determine account ownership; an official Steam install is the clearest reference for testing.'
}

$taskLogSummary = [ordered]@{
    skipped = [bool]$SkipLogScan
    provenance = 'Historical Unity log for this Windows profile; its game-copy path is not inspected or exported.'
    currentCopyProven = $false
    exists = $false
    sampledTailLines = 0
    sizeBytes = $null
    modifiedAtUtc = $null
    historicalDirect3D11Observed = $false
    categories = @()
    sampledMethodNames = @()
}
if (-not $SkipLogScan) {
    $taskLocalLow = Join-Path (Split-Path -Parent ([Environment]::GetFolderPath('LocalApplicationData'))) 'LocalLow'
    $taskLogPath = Join-Path $taskLocalLow 'Kinetic Games\Phasmophobia\Player.log'
    if (Test-Path -LiteralPath $taskLogPath -PathType Leaf) {
        $taskLogSummary.exists = $true
        try {
            $taskLogItem = Get-Item -LiteralPath $taskLogPath
            $taskLogSummary.sizeBytes = $taskLogItem.Length
            $taskLogSummary.modifiedAtUtc = $taskLogItem.LastWriteTimeUtc.ToString('o')
            $taskHead = @(Get-Content -LiteralPath $taskLogPath -TotalCount 200)
            $taskTail = @(Get-Content -LiteralPath $taskLogPath -Tail $LogTailLines)
            $taskLogSummary.sampledTailLines = $taskTail.Count
            $taskLogSummary.historicalDirect3D11Observed = @($taskHead | Where-Object { $_ -match 'Version:\s+Direct3D 11' }).Count -gt 0
            $taskCategoryPatterns = [ordered]@{
                NullReferenceException = 'NullReferenceException'
                DllNotFoundException = 'DllNotFoundException'
                EntryPointNotFoundException = 'EntryPointNotFoundException'
                BadImageFormatException = 'BadImageFormatException'
                FileNotFoundException = 'FileNotFoundException'
                OutOfMemoryException = 'OutOfMemoryException'
                AuthenticationException = 'AuthenticationException|AuthenticationError'
                SteamInitializationFailure = '(?i)SteamAPI\.Init.*fail|steam.*not initialized'
                GraphicsDeviceFailure = '(?i)failed to (?:initialize|create).*(?:graphics|d3d)|DXGI_ERROR_DEVICE_(?:REMOVED|HUNG)'
            }
            foreach ($taskCategory in $taskCategoryPatterns.Keys) {
                $taskCount = @($taskTail | Where-Object { $_ -match $taskCategoryPatterns[$taskCategory] }).Count
                if ($taskCount -gt 0) {
                    $taskLogSummary.categories += [pscustomobject]@{
                        category = $taskCategory
                        mentionsInTail = $taskCount
                    }
                }
            }
            $taskMethods = @($taskTail | ForEach-Object {
                if ($_ -match '^\s+at\s+([A-Za-z][A-Za-z0-9_.<>\x60+]{1,180})\s*\(') { $Matches[1] }
            } | Group-Object | Sort-Object Count -Descending | Select-Object -First 12 | ForEach-Object {
                [pscustomobject]@{ method = $_.Name; mentionsInTail = $_.Count }
            })
            $taskLogSummary.sampledMethodNames = $taskMethods
            if ($taskLogSummary.categories.Count -gt 0) {
                Add-Finding 'HISTORICAL_LOG_ERRORS' 'warning' 'The sampled end of the existing Unity log contains errors. Counts describe an earlier run and may not describe the current copy or an active problem.'
            }
        } catch {
            Add-Finding 'LOG_READ_FAILED' 'info' 'The existing Unity log could not be sampled; no raw log content was copied.'
        }
    }
}
$taskReport.historicalPlayerLog = $taskLogSummary
$taskReport.findings = @($taskFindings.ToArray())
$taskReport.nextManualChecks = @(
    'Record the game-menu version on every computer; use the same game version, branch, and multiplayer backend.',
    'For an official installation, start Steam, sign in, and launch the game from its library.',
    'Check that the lobby opens, then test a private lobby join with the intended Windows and Mac players.',
    'Verify microphone permission, selected input device, push-to-talk, and proximity/radio voice.',
    'Complete one short contract, return to the lobby, and reconnect before relying on the setup.'
)
$taskReport.result = if (@($taskFindings | Where-Object { $_.severity -eq 'error' }).Count -gt 0) {
    'missing_or_unreadable_prerequisites'
} else {
    'manual_launch_and_multiplayer_test_required'
}

try {
    $taskJson = $taskReport | ConvertTo-Json -Depth 10
    $taskOutputFullPath = [IO.Path]::GetFullPath($OutputPath)
    $taskGameFullPath = [IO.Path]::GetFullPath($GamePath).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if ([IO.Path]::GetExtension($taskOutputFullPath) -ne '.json' -or
        $taskOutputFullPath.StartsWith($taskGameFullPath, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The output must be a JSON report outside the game directory.'
    }
    $taskOutputParent = Split-Path -Parent $taskOutputFullPath
    if (-not (Test-Path -LiteralPath $taskOutputParent -PathType Container)) {
        throw 'The output directory does not exist.'
    }
    [IO.File]::WriteAllText($taskOutputFullPath, $taskJson, (New-Object Text.UTF8Encoding($false)))
} catch {
    Write-Error 'Could not write the diagnostic report. Choose a .json file in an existing writable directory outside the game directory.' -ErrorAction Continue
    exit 3
}

Write-Host 'Windows diagnostic report saved.'
Write-Host ('Result: ' + $taskReport.result)
foreach ($taskFinding in $taskFindings) {
    Write-Host ('[' + $taskFinding.severity + '] ' + $taskFinding.message)
}
Write-Host 'No game launch or multiplayer test was performed.'
if ($taskReport.result -eq 'missing_or_unreadable_prerequisites') { exit 2 }
exit 0
