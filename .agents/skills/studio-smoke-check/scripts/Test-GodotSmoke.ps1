#Requires -Version 7.4

param(
    [string]$Godot,
    [ValidatePattern('^[a-z0-9-]+$')]
    [string[]]$Scenario
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../../..')).ProviderPath
$localConfig = Join-Path $repoRoot '.godot-mcp.json'
if (-not $Godot -and (Test-Path -LiteralPath $localConfig -PathType Leaf)) {
    $Godot = (Get-Content -Raw -Encoding utf8 -LiteralPath $localConfig | ConvertFrom-Json).godotPath
}
if (-not $Godot) {
    $Godot = $env:GODOT_PATH
}
if (-not $Godot) {
    $Godot = 'godot'
}
$godotCommand = Get-Command -Name $Godot -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $godotCommand) {
    throw 'Godot was not found. Pass the Godot console executable with -Godot or set GODOT_PATH.'
}

$godotExe = $godotCommand.Source
$version = & $godotExe --version
if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.') {
    throw "Expected a Godot 4 console executable, got '$version'."
}
Write-Host "Godot $version"

function Invoke-GodotCheck {
    param(
        [string]$Step,
        [string[]]$Options,
        [string]$ExpectedOutput
    )

    Write-Host "== $Step =="
    $lines = & $godotExe --headless --path $testProject @Options 2>&1
    $godotExit = $LASTEXITCODE
    $lines | Out-Host
    if ($godotExit -ne 0 -or $lines -match '^\s*(?:SCRIPT ERROR|USER ERROR|ERROR):') {
        throw "$Step failed (Godot exit $godotExit)."
    }
    if ($ExpectedOutput -and $lines -cnotcontains $ExpectedOutput) {
        throw "$Step did not reach its completion marker."
    }
}

$scratch = [IO.Directory]::CreateTempSubdirectory('fiefdom-smoke-')
$testProject = Join-Path $scratch.FullName 'project'
$previousAppData = $env:APPDATA

try {
    $copyOptions = @(
        '/E', '/XJ', '/R:0', '/W:0', '/NFL', '/NDL', '/NJH', '/NJS', '/NP',
        '/XD', $scratch.FullName, '.git', '.godot', '.claude', '.codex', 'godot-mcp-ultimate', 'build',
        '/XF', '.git', '.godot-mcp.json'
    )
    & robocopy.exe $repoRoot $testProject @copyOptions
    if ($LASTEXITCODE -ge 8) {
        throw "Copying the project failed (robocopy exit $LASTEXITCODE)."
    }

    $env:APPDATA = (New-Item -ItemType Directory -Path (Join-Path $scratch.FullName 'profile')).FullName
    Invoke-GodotCheck -Step 'Resource import' -Options @('--import')

    $scriptPaths = Get-ChildItem -LiteralPath (Join-Path $testProject 'scripts') -Filter '*.gd' -Recurse -File |
        ForEach-Object { 'res://' + [IO.Path]::GetRelativePath($testProject, $_.FullName).Replace('\', '/') }
    $parseOptions = @('--script', 'res://.agents/skills/studio-smoke-check/scripts/godot-parse-check.gd', '--')
    Invoke-GodotCheck -Step 'GDScript loading' -Options ($parseOptions + $scriptPaths)
    Invoke-GodotCheck -Step 'Main scene startup' -Options @('--quit-after', '120')
    foreach ($name in $Scenario) {
        $env:APPDATA = (New-Item -ItemType Directory -Path (Join-Path $scratch.FullName "scenario-$name")).FullName
        Invoke-GodotCheck -Step "Scenario $name" -ExpectedOutput 'SCENARIO_OK' -Options @(
            '--fixed-fps', '60', '--quit-after', '12000', '--script', "res://tests/$name.gd"
        )
    }
    Write-Host 'Godot smoke checks passed.'
} finally {
    $env:APPDATA = $previousAppData
    $tempRoot = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath([IO.Path]::GetTempPath()))
    $resolvedScratch = Get-Item -LiteralPath $scratch.FullName -Force
    if ($resolvedScratch.Parent.FullName -eq $tempRoot -and
        $resolvedScratch.Name -like 'fiefdom-smoke-*' -and
        -not ($resolvedScratch.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Remove-Item -LiteralPath $resolvedScratch.FullName -Recurse -Force
    }
}
