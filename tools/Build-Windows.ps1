#Requires -Version 7.4

param(
    [string]$Godot,
    [string]$TemplatesDirectory
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
$engineVersion = '4.7.2'
$templateVersion = "$engineVersion.stable"
$localConfig = Join-Path $repo '.godot-mcp.json'
if (-not $Godot -and (Test-Path -LiteralPath $localConfig -PathType Leaf)) {
    $Godot = (Get-Content -Raw -Encoding utf8 -LiteralPath $localConfig | ConvertFrom-Json).godotPath
}
if (-not $Godot) { $Godot = $env:GODOT_PATH }
if (-not $Godot) { $Godot = 'godot' }
$godotExe = (Get-Command -Name $Godot -CommandType Application | Select-Object -First 1).Source
$actualVersion = & $godotExe --version
if ($LASTEXITCODE -ne 0 -or $actualVersion -notlike "$templateVersion.*") {
    throw "Expected Godot $templateVersion console executable, got '$actualVersion'."
}

$originalAppData = $env:APPDATA
if (-not $TemplatesDirectory) {
    $TemplatesDirectory = Join-Path $originalAppData "Godot/export_templates/$templateVersion"
}
$templateFiles = @('windows_release_x86_64.exe', 'icudt_godot.dat')
foreach ($file in $templateFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $TemplatesDirectory $file) -PathType Leaf)) {
        throw "Missing $file in '$TemplatesDirectory'. Install the Godot $engineVersion export templates or pass -TemplatesDirectory."
    }
}

$projectConfig = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $repo 'project.godot')
$gameVersion = [regex]::Match($projectConfig, '(?m)^config/version="(\d+\.\d+\.\d+)"\s*$').Groups[1].Value
if (-not $gameVersion) { throw 'Set the version in project.godot using a major.minor.patch number.' }

$buildDir = (New-Item -ItemType Directory -Force -Path (Join-Path $repo 'build')).FullName
$zipPath = Join-Path $buildDir "Fiefdom-$gameVersion-Windows-x64.zip"
$pendingZip = Join-Path $buildDir ('.pending-' + [guid]::NewGuid() + '.zip')
$scratch = [IO.Directory]::CreateTempSubdirectory('fiefdom-export-')
$project = Join-Path $scratch.FullName 'project'

function Invoke-GodotExportStep([string]$Step, [string[]]$Options) {
    Write-Host "== $Step =="
    $lines = & $godotExe --headless --path $project @Options 2>&1
    $code = $LASTEXITCODE
    $lines | Out-Host
    if ($code -ne 0 -or $lines -cmatch '^\s*(?:SCRIPT ERROR|USER ERROR|ERROR|WARNING):') {
        throw "$Step failed (Godot exit $code)."
    }
}

try {
    New-Item -ItemType Directory -Path $project | Out-Null
    foreach ($entry in @('addons', 'assets', 'resources', 'scenes', 'scripts', 'project.godot', 'export_presets.cfg', 'icon.svg', 'icon.svg.import')) {
        Copy-Item -LiteralPath (Join-Path $repo $entry) -Destination $project -Recurse
    }

    $env:APPDATA = Join-Path $scratch.FullName 'export-profile'
    $templates = (New-Item -ItemType Directory -Path (Join-Path $env:APPDATA "Godot/export_templates/$templateVersion")).FullName
    foreach ($file in $templateFiles) {
        Copy-Item -LiteralPath (Join-Path $TemplatesDirectory $file) -Destination $templates
    }

    $package = (New-Item -ItemType Directory -Path (Join-Path $scratch.FullName 'package')).FullName
    Invoke-GodotExportStep 'Resource import' @('--import')
    Invoke-GodotExportStep 'Windows x64 release export' @('--export-release', 'Windows Desktop', (Join-Path $package 'Fiefdom.exe'))
    foreach ($file in @('Fiefdom.exe', 'Fiefdom.pck')) {
        if ((Get-Item -LiteralPath (Join-Path $package $file)).Length -eq 0) {
            throw "The exported $file is empty."
        }
    }
    Copy-Item -LiteralPath (Join-Path $repo 'docs/Windows试玩说明.txt') -Destination (Join-Path $package 'README.txt')
    Copy-Item -LiteralPath (Join-Path $repo "docs/licenses/Godot-$engineVersion") -Destination $package -Recurse
    Copy-Item -LiteralPath (Join-Path $repo 'docs/licenses/MaShanZheng-OFL.txt') -Destination $package
    $archive = [IO.Compression.ZipFile]::Open($pendingZip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $files = [IO.Directory]::GetFiles($package, '*', [IO.SearchOption]::AllDirectories)
        [Array]::Sort($files, [StringComparer]::Ordinal)
        $archiveDate = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
        foreach ($file in $files) {
            $name = [IO.Path]::GetRelativePath($package, $file).Replace('\', '/')
            $entry = $archive.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = $archiveDate
            $targetStream = $entry.Open()
            try {
                $sourceStream = [IO.File]::OpenRead($file)
                try { $sourceStream.CopyTo($targetStream) } finally { $sourceStream.Dispose() }
            } finally {
                $targetStream.Dispose()
            }
        }
    } finally {
        $archive.Dispose()
    }

    Write-Host '== Extracted release smoke check =='
    $extracted = Join-Path $scratch.FullName 'extracted'
    Expand-Archive -LiteralPath $pendingZip -DestinationPath $extracted
    $env:APPDATA = (New-Item -ItemType Directory -Path (Join-Path $scratch.FullName 'player-profile')).FullName
    $runLog = Join-Path $scratch.FullName 'release.log'
    $game = Start-Process -FilePath (Join-Path $extracted 'Fiefdom.exe') -WorkingDirectory $extracted -WindowStyle Hidden -PassThru -ArgumentList @(
        '--headless', '--fixed-fps', '60', '--quit-after', '180', '--log-file', ('"' + $runLog + '"')
    )
    if (-not $game.WaitForExit(90000)) {
        $game.Kill()
        $game.WaitForExit()
        throw 'The extracted game did not exit during its smoke check.'
    }
    $runLines = Get-Content -Encoding utf8 -LiteralPath $runLog
    $runLines | Out-Host
    if ($game.ExitCode -ne 0 -or $runLines -cnotcontains 'Fiefdom title ready' -or $runLines -cmatch '^\s*(?:SCRIPT ERROR|USER ERROR|ERROR|WARNING):') {
        throw "Extracted game failed to reach the title (exit $($game.ExitCode))."
    }

    [IO.File]::Move($pendingZip, $zipPath, $true)
    Get-Item -LiteralPath $zipPath
} finally {
    $env:APPDATA = $originalAppData
    if (Test-Path -LiteralPath $pendingZip -PathType Leaf) {
        Remove-Item -LiteralPath $pendingZip
    }
    $tempRoot = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath([IO.Path]::GetTempPath()))
    $resolvedScratch = Get-Item -LiteralPath $scratch.FullName -Force
    if ($resolvedScratch.Parent.FullName -eq $tempRoot -and
        $resolvedScratch.Name -like 'fiefdom-export-*' -and
        -not ($resolvedScratch.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Remove-Item -LiteralPath $resolvedScratch.FullName -Recurse -Force
    }
}
