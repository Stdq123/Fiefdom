#Requires -Version 7.4

param(
    [Parameter(Mandatory)]
    [string]$Package,
    [string[]]$LegacyPackage,
    [string]$EvidenceDirectory,
    [switch]$Capture,
    [switch]$Soak,
    [switch]$Rations,
    [switch]$Gamepad,
    [switch]$ManagementNavigation,
    [switch]$SixArts,
    [switch]$BowAim,
    [switch]$RaidFeedback,
    [switch]$WinterSupper,
    [switch]$WinterRoadRations,
    [switch]$KeyBindings,
    [switch]$SummerRaft,
    [switch]$TitlePresentation,
    [switch]$ProcessRestart,
    [switch]$Backpack,
    [switch]$HallDecor,
    [switch]$RouteGoals,
    [switch]$Opening,
    [switch]$FieldPlanning,
    [switch]$StewardCampaign,
    [switch]$OrderCampaign,
    [switch]$FieldRotationPlans,
    [switch]$SilkMarket,
    [switch]$SilkInterior,
    [switch]$NeighborHandoff,
    [switch]$AmbienceTravel,
    [switch]$EstateTerrain,
    [switch]$CanalDoors,
    [switch]$CanalFlow,
    [switch]$FieldWorksites,
    [switch]$FieldStroke,
    [switch]$FieldRoutes,
    [switch]$MorningRecord,
    [switch]$PavilionEvening,
    [switch]$SouthRoad,
    [switch]$WatchRelief,
    [switch]$RavineLayout,
    [switch]$FishMarketOrders,
    [switch]$MarketWayfinding
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
$packagePath = (Resolve-Path -LiteralPath $Package).ProviderPath
if ($Capture -and -not ('Fiefdom.Tools.IsolatedDesktop' -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'IsolatedDesktop.cs')
}
if (-not $EvidenceDirectory) {
    $name = [IO.Path]::GetFileNameWithoutExtension($packagePath)
    $EvidenceDirectory = Join-Path $repo "build/$name-verification"
}
$evidence = (New-Item -ItemType Directory -Force -Path $EvidenceDirectory).FullName
$scratch = [IO.Directory]::CreateTempSubdirectory('fiefdom-smoke-release-')
$originalAppData = $env:APPDATA

function Start-VerifiedGame {
    param(
        [string]$Directory,
        [string]$Profile,
        [string]$Name,
        [string]$Replay,
        [string]$Resolution,
        [switch]$ResumeProfile
    )

    $profilePath = Join-Path $scratch.FullName $Profile
    $env:APPDATA = if ($ResumeProfile) {
        (Resolve-Path -LiteralPath $profilePath).ProviderPath
    } else {
        (New-Item -ItemType Directory -Path $profilePath).FullName
    }
    $log = Join-Path $evidence "$Name.log"
    $frameLimit = if ($Replay -like '*-steward' -or $Replay -eq 'reformed-orders') { '42000' } elseif ($Replay) { '12000' } else { '180' }
    $arguments = @('--quit-after', $frameLimit, '--log-file', ('"' + $log + '"'))
    $arguments += if ($Replay -eq 'soak') {
        '--max-fps', '60', '--audio-driver', 'Dummy'
    } elseif ($Resolution -and $Replay -in 'ambience-travel', 'raid-feedback', 'west-market') {
        # Audio playback and recordings follow wall time.
        '--max-fps', '60'
    } else {
        '--fixed-fps', '60'
    }
    if ($Resolution) {
        $screens = (New-Item -ItemType Directory -Force -Path (Join-Path $evidence $Resolution)).FullName
        $arguments += @('--windowed', '--disable-vsync', '--resolution', $Resolution)
    } else {
        $arguments += '--headless'
    }
    if ($Replay) {
        $arguments += @('--', $Replay)
        if ($Resolution) { $arguments += ('"' + $screens + '"') }
    }
    Write-Host "== $Name =="
    $executable = Join-Path $Directory 'Fiefdom.exe'
    if ($Resolution) {
        $isolation = ''
        $exitCode = [Fiefdom.Tools.IsolatedDesktop]::Run($executable, ($arguments -join ' '), $Directory, 180000, [ref]$isolation)
        Write-Host $isolation
    } else {
        $process = Start-Process -FilePath $executable -WorkingDirectory $Directory -WindowStyle Hidden -PassThru -ArgumentList $arguments
        try {
            if (-not $process.WaitForExit(180000)) {
                $process.Kill()
                $process.WaitForExit()
                throw "$Name timed out. See $log"
            }
            $exitCode = $process.ExitCode
        } finally {
            $process.Dispose()
        }
    }
    $lines = Get-Content -LiteralPath $log -Encoding utf8
    $marker = if ($Replay) { 'SCENARIO_OK' } else { 'Fiefdom title ready' }
    $lines | Where-Object { $_ -match '^(CAMPAIGN_|RELEASE_|LEGACY_|RATIONS_|RESEARCH_RATIONS_|GAMEPAD_|DRIVING_|BOW_AIM_|WINTER_|BINDING_|RAFT_|TITLE_|BACKPACK_|DECOR_|ROUTE_|COUNCIL_PREP_|COUNCIL_SILK_|DIRECTION_|PLAN_|TRIBUTE_|FIELD_ROTATION_|SILK_MARKET_|SILK_BATCH_|HANDOFF_|AMBIENCE_|TERRAIN_|CANAL_DOOR_|SPRING_|ESTATE_PROGRESS_|ESTATE_PROVISIONS|RECRUITMENT_|FIELD_ACCESS_|FIELD_STROKE_|WORKSITE_|FIELD_ROUTE_|FIELD_NIGHT_|MORNING_|PAVILION_EVENING_|FISH_MARKET_|RAVINE_MAP_|SHORTCUT_|TRAP_|MARKET_WAYFINDING_|SCENARIO_OK|Fiefdom title ready|Vulkan)' } | Out-Host
    if ($exitCode -ne 0 -or $lines -cnotcontains $marker -or $lines -cmatch '^\s*(?:SCRIPT ERROR|USER ERROR|ERROR|WARNING):') {
        throw "$Name failed (exit $exitCode). See $log"
    }
}

function Install-Replay([string]$Directory) {
    $testDirectory = (New-Item -ItemType Directory -Path (Join-Path $Directory 'tests')).FullName
    foreach ($file in 'ReleaseReplay.tscn', 'ReleaseReplay.gd', 'CampaignReplay.gd', 'NightRationsReplay.gd', 'RationPriorityReplay.gd', 'RetainerReturnReplay.gd', 'GamepadReplay.gd', 'SixArtsReplay.gd', 'BowAimReplay.gd', 'WinterSupperReplay.gd', 'KeyBindingsReplay.gd', 'SummerRaftReplay.gd', 'TitlePresentationReplay.gd', 'HallInteriorReplay.gd', 'HallDecorReplay.gd', 'TaxCouncilReplay.gd', 'RouteGoalsReplay.gd', 'CouncilPrepReplay.gd', 'EstateDirectionsReplay.gd', 'FieldSeedPlanReplay.gd', 'FieldPlanningReplay.gd', 'FieldRotationPlanReplay.gd', 'WestMarketReplay.gd', 'SilkMarketReplay.gd', 'SilkBatchReplay.gd', 'NeighborHandoffReplay.gd', 'AmbienceTravelReplay.gd', 'BuildingScaleReplay.gd', 'EstateTerrainReplay.gd', 'FieldWorksiteReplay.gd', 'FieldRoutesReplay.gd', 'PavilionEveningReplay.gd', 'FishMarketReplay.gd', 'FishingJourneyReplay.gd', 'MarketWayfindingReplay.gd') {
        Copy-Item -LiteralPath (Join-Path $repo "tests/$file") -Destination $testDirectory
    }
    Copy-Item -LiteralPath (Join-Path $repo 'tests/CanalDoorReplay.gd'), (Join-Path $repo 'tests/CanalFlowReplay.gd'), (Join-Path $repo 'tests/EstateProgressReplay.gd'), (Join-Path $repo 'tests/SilkInteriorReplay.gd') -Destination $testDirectory
    Copy-Item -LiteralPath (Join-Path $repo 'tests/IrrigationFlowReplay.gd') -Destination $testDirectory
    Copy-Item -LiteralPath (Join-Path $repo 'tests/TributePlanReplay.gd') -Destination $testDirectory
    Copy-Item -LiteralPath (Join-Path $repo 'tests/BackpackReplay.gd') -Destination $testDirectory
    Copy-Item -LiteralPath (Join-Path $repo 'tests/WestRoadReplay.gd') -Destination $testDirectory
    Copy-Item -LiteralPath (Join-Path $repo 'tests/OrderPreparationReplay.gd'), (Join-Path $repo 'tests/SecondYearOrdersReplay.gd') -Destination $testDirectory
    Copy-Item -LiteralPath (Join-Path $repo 'tests/WatchReliefReplay.gd') -Destination $testDirectory
    Copy-Item -LiteralPath (Join-Path $repo 'tests/SeedGardenReplay.gd') -Destination $testDirectory
    Copy-Item -LiteralPath (Join-Path $repo 'tests/ResearchRationsReplay.gd') -Destination $testDirectory
    Copy-Item -LiteralPath (Join-Path $repo 'tests/FieldStrokeReplay.gd') -Destination $testDirectory
    Copy-Item -LiteralPath (Join-Path $repo 'tests/ManagementNavigationReplay.gd') -Destination $testDirectory
    Copy-Item -LiteralPath (Join-Path $repo 'tests/EndingFilmReplay.gd') -Destination $testDirectory
    Copy-Item -LiteralPath (Join-Path $repo 'tests/RaidReadinessReplay.gd') -Destination $testDirectory
    Copy-Item -LiteralPath (Join-Path $repo 'tests/PavilionVisitReplay.gd') -Destination $testDirectory
    Copy-Item -LiteralPath (Join-Path $repo 'tests/RecruitmentLedgerReplay.gd') -Destination $testDirectory
    Copy-Item -LiteralPath (Join-Path $repo 'tests/RavineShortcutReplay.gd') -Destination $testDirectory
    foreach ($file in 'MarketOrderReplay.gd', 'AutumnExhibitReplay.gd', 'SheepfoldReplay.gd', 'RavineMapReplay.gd', 'CreekTrapReplay.gd', 'FieldNightReplay.gd', 'CouncilSilkReplay.gd') {
        Copy-Item -LiteralPath (Join-Path $repo "tests/$file") -Destination $testDirectory
    }
    @'
[application]
run/main_scene="res://tests/ReleaseReplay.tscn"

[display]
window/size/no_focus=true
'@ | Set-Content -LiteralPath (Join-Path $Directory 'override.cfg') -Encoding utf8
}

try {
    $release = Join-Path $scratch.FullName 'unpacked Windows release'
    Expand-Archive -LiteralPath $packagePath -DestinationPath $release
    if (Test-Path -LiteralPath (Join-Path $release 'override.cfg')) {
        throw 'The distributed package must start without a verification override.'
    }
    $runtime = @('Fiefdom.exe', 'Fiefdom.pck') | ForEach-Object { Get-FileHash -LiteralPath (Join-Path $release $_) }
    Start-VerifiedGame -Directory $release -Profile 'startup' -Name 'startup'
    # The fixture lives alongside the unpacked files. The distributed EXE and PCK are used byte for byte.
    Install-Replay $release
    $fullResolution = if ($Capture) { '1920x1080' } else { '' }
    foreach ($route in 'traditional', 'reformed', 'defeat') {
        Start-VerifiedGame -Directory $release -Profile $route -Name $route -Replay $route -Resolution $fullResolution
    }
    Start-VerifiedGame -Directory $release -Profile 'research' -Name 'research' -Replay 'research'
    if ($Gamepad) {
        Start-VerifiedGame -Directory $release -Profile 'gamepad' -Name 'gamepad' -Replay 'gamepad'
    }
    if ($ManagementNavigation) {
        Start-VerifiedGame -Directory $release -Profile 'management-navigation' -Name 'management-navigation' -Replay 'management-navigation'
    }
    if ($SixArts) {
        Start-VerifiedGame -Directory $release -Profile 'six-arts' -Name 'six-arts' -Replay 'six-arts'
    }
    if ($BowAim) {
        Start-VerifiedGame -Directory $release -Profile 'bow-aim' -Name 'bow-aim' -Replay 'bow-aim'
    }
    if ($RaidFeedback) {
        Start-VerifiedGame -Directory $release -Profile 'raid-feedback' -Name 'raid-feedback' -Replay 'raid-feedback' -Resolution $fullResolution
    }
    if ($WinterSupper) {
        Start-VerifiedGame -Directory $release -Profile 'winter-supper' -Name 'winter-supper' -Replay 'winter-supper'
    }
    if ($WinterRoadRations) {
        Start-VerifiedGame -Directory $release -Profile 'winter-road-rations' -Name 'winter-road-rations' -Replay 'winter-road-rations'
    }
    if ($SummerRaft) {
        Start-VerifiedGame -Directory $release -Profile 'summer-raft' -Name 'summer-raft' -Replay 'summer-raft'
    }
    if ($TitlePresentation) {
        Start-VerifiedGame -Directory $release -Profile 'title-presentation' -Name 'title-presentation' -Replay 'title-presentation' -Resolution $fullResolution
    }
    if ($ProcessRestart) {
        foreach ($route in 'traditional', 'reformed') {
            $profile = "restart-$route"
            Start-VerifiedGame -Directory $release -Profile $profile -Name "ending-write-$route" -Replay "save-ending-$route"
            Start-VerifiedGame -Directory $release -Profile $profile -Name "ending-restart-$route" -Replay "resume-ending-$route" -ResumeProfile
        }
    }
    if ($Backpack) {
        Start-VerifiedGame -Directory $release -Profile 'backpack' -Name 'backpack' -Replay 'backpack'
    }
    if ($HallDecor) {
        Start-VerifiedGame -Directory $release -Profile 'hall-decor' -Name 'hall-decor' -Replay 'hall-decor'
    }
    if ($RouteGoals) {
        Start-VerifiedGame -Directory $release -Profile 'council-prep' -Name 'council-prep' -Replay 'council-prep' -Resolution $fullResolution
        Start-VerifiedGame -Directory $release -Profile 'council-petition' -Name 'council-petition' -Replay 'council-petition'
        Start-VerifiedGame -Directory $release -Profile 'council-silk' -Name 'council-silk' -Replay 'council-silk'
        Start-VerifiedGame -Directory $release -Profile 'route-goals' -Name 'route-goals' -Replay 'route-goals'
        Start-VerifiedGame -Directory $release -Profile 'ending-film' -Name 'ending-film' -Replay 'ending-film'
    }
    if ($Opening) {
        Start-VerifiedGame -Directory $release -Profile 'opening' -Name 'opening' -Replay 'estate-directions' -Resolution $fullResolution
        Start-VerifiedGame -Directory $release -Profile 'tribute-plan' -Name 'tribute-plan' -Replay 'tribute-plan'
        Start-VerifiedGame -Directory $release -Profile 'estate-progress' -Name 'estate-progress' -Replay 'estate-progress' -Resolution $fullResolution
        Start-VerifiedGame -Directory $release -Profile 'recruitment-ledger' -Name 'recruitment-ledger' -Replay 'recruitment-ledger' -Resolution $fullResolution
    }
    if ($FieldPlanning) {
        Start-VerifiedGame -Directory $release -Profile 'field-planning' -Name 'field-planning' -Replay 'field-planning'
        Start-VerifiedGame -Directory $release -Profile 'field-steward' -Name 'field-steward' -Replay 'field-steward'
    }
    if ($StewardCampaign) {
        foreach ($name in 'traditional-steward', 'reformed-steward') {
            Start-VerifiedGame -Directory $release -Profile $name -Name $name -Replay $name
        }
        Start-VerifiedGame -Directory $release -Profile 'reformed-first-steward' -Name 'reformed-first-steward' -Replay 'reformed-first-steward' -Resolution $fullResolution
    }
    if ($OrderCampaign) {
        Start-VerifiedGame -Directory $release -Profile 'freight-wait' -Name 'freight-wait' -Replay 'freight-wait' -Resolution $fullResolution
        Start-VerifiedGame -Directory $release -Profile 'reformed-orders' -Name 'reformed-orders' -Replay 'reformed-orders' -Resolution $fullResolution
    }
    if ($FieldRotationPlans) {
        Start-VerifiedGame -Directory $release -Profile 'field-rotation-plans' -Name 'field-rotation-plans' -Replay 'field-rotation-plans'
    }
    if ($SilkMarket) {
        Start-VerifiedGame -Directory $release -Profile 'silk-market' -Name 'silk-market' -Replay 'silk-market'
        Start-VerifiedGame -Directory $release -Profile 'silk-batches' -Name 'silk-batches' -Replay 'silk-batches'
    }
    if ($SilkInterior) {
        Start-VerifiedGame -Directory $release -Profile 'silk-interior' -Name 'silk-interior' -Replay 'silk-interior'
    }
    if ($NeighborHandoff) {
        Start-VerifiedGame -Directory $release -Profile 'neighbor-handoff' -Name 'neighbor-handoff' -Replay 'neighbor-handoff'
    }
    if ($AmbienceTravel) {
        Start-VerifiedGame -Directory $release -Profile 'ambience-travel' -Name 'ambience-travel' -Replay 'ambience-travel' -Resolution $fullResolution
    }
    if ($EstateTerrain) {
        Start-VerifiedGame -Directory $release -Profile 'estate-terrain' -Name 'estate-terrain' -Replay 'estate-terrain' -Resolution $fullResolution
    }
    if ($CanalFlow) {
        Start-VerifiedGame -Directory $release -Profile 'canal-flow' -Name 'canal-flow' -Replay 'canal-flow' -Resolution $fullResolution
    }
    if ($CanalDoors) {
        Start-VerifiedGame -Directory $release -Profile 'canal-doors' -Name 'canal-doors' -Replay 'canal-doors'
        Start-VerifiedGame -Directory $release -Profile 'irrigation-flow' -Name 'irrigation-flow' -Replay 'irrigation-flow' -Resolution $fullResolution
    }
    if ($FieldWorksites) {
        Start-VerifiedGame -Directory $release -Profile 'field-worksites' -Name 'field-worksites' -Replay 'field-worksites'
    }
    if ($FieldStroke) {
        Start-VerifiedGame -Directory $release -Profile 'field-stroke' -Name 'field-stroke' -Replay 'field-stroke' -Resolution $fullResolution
    }
    if ($FieldRoutes) {
        Start-VerifiedGame -Directory $release -Profile 'field-routes' -Name 'field-routes' -Replay 'field-routes'
    }
    if ($MorningRecord) {
        Start-VerifiedGame -Directory $release -Profile 'field-nights' -Name 'field-nights' -Replay 'field-nights' -Resolution $fullResolution
    }
    if ($PavilionEvening) {
        Start-VerifiedGame -Directory $release -Profile 'pavilion-evening' -Name 'pavilion-evening' -Replay 'pavilion-evening'
        Start-VerifiedGame -Directory $release -Profile 'pavilion-stories' -Name 'pavilion-stories' -Replay 'pavilion-stories' -Resolution $fullResolution
    }
    if ($WatchRelief) {
        Start-VerifiedGame -Directory $release -Profile 'watch-relief' -Name 'watch-relief' -Replay 'watch-relief'
    }
    if ($SouthRoad) {
        Start-VerifiedGame -Directory $release -Profile 'market-orders' -Name 'market-orders' -Replay 'market-orders' -Resolution $fullResolution
        foreach ($name in 'summer-rice', 'order-preparation', 'watch-relief', 'seed-garden', 'autumn-exhibit', 'sheepfold', 'meadow-fodder') {
            Start-VerifiedGame -Directory $release -Profile $name -Name $name -Replay $name
        }
    }
    if ($RavineLayout) {
        Start-VerifiedGame -Directory $release -Profile 'ravine-map' -Name 'ravine-map' -Replay 'ravine-map' -Resolution $fullResolution
        Start-VerifiedGame -Directory $release -Profile 'creek-traps' -Name 'creek-traps' -Replay 'creek-traps'
        Start-VerifiedGame -Directory $release -Profile 'ravine-shortcut' -Name 'ravine-shortcut' -Replay 'ravine-shortcut'
    }
    if ($FishMarketOrders) {
        Start-VerifiedGame -Directory $release -Profile 'fish-market-orders' -Name 'fish-market-orders' -Replay 'fish-market-orders' -Resolution $fullResolution
    }
    if ($MarketWayfinding) {
        Start-VerifiedGame -Directory $release -Profile 'west-market' -Name 'west-market' -Replay 'west-market' -Resolution $fullResolution
        Start-VerifiedGame -Directory $release -Profile 'west-road' -Name 'west-road' -Replay 'west-road' -Resolution $fullResolution
        Start-VerifiedGame -Directory $release -Profile 'market-wayfinding' -Name 'market-wayfinding' -Replay 'market-wayfinding' -Resolution $fullResolution
        Start-VerifiedGame -Directory $release -Profile 'fishing-journey' -Name 'fishing-journey' -Replay 'fishing-journey'
    }
    if ($KeyBindings) {
        Start-VerifiedGame -Directory $release -Profile 'key-bindings' -Name 'key-bindings' -Replay 'key-bindings'
        Start-VerifiedGame -Directory $release -Profile 'key-bindings' -Name 'key-bindings-reload' -Replay 'key-bindings-reload'
    }
    if ($Rations) {
        Start-VerifiedGame -Directory $release -Profile 'night-rations' -Name 'night-rations' -Replay 'night-rations' -Resolution $fullResolution
        foreach ($name in 'research-rations', 'ration-priority', 'retainer-return', 'traditional-rations', 'reformed-rations') {
            Start-VerifiedGame -Directory $release -Profile $name -Name $name -Replay $name
        }
    }
    foreach ($previousPackage in $LegacyPackage) {
        $oldPackage = (Resolve-Path -LiteralPath $previousPackage).ProviderPath
        $oldName = [IO.Path]::GetFileNameWithoutExtension($oldPackage)
        $legacy = Join-Path $scratch.FullName "unpacked $oldName"
        Expand-Archive -LiteralPath $oldPackage -DestinationPath $legacy
        Install-Replay $legacy
        Start-VerifiedGame -Directory $legacy -Profile "legacy-$oldName" -Name "legacy-create-$oldName" -Replay 'legacy-create'
        Start-VerifiedGame -Directory $release -Profile "legacy-$oldName" -Name "legacy-continue-$oldName" -Replay 'legacy-continue' -ResumeProfile
    }
    if ($Capture) {
        foreach ($size in $fullResolution, '1024x768') {
            Start-VerifiedGame -Directory $release -Profile "render-$size" -Name "render-$size" -Replay 'visual' -Resolution $size
        }
        if ($StewardCampaign) {
            Start-VerifiedGame -Directory $release -Profile 'first-steward-compact' -Name 'reformed-first-steward-1024x768' -Replay 'reformed-first-steward' -Resolution '1024x768'
        }
        if ($OrderCampaign) {
            Start-VerifiedGame -Directory $release -Profile 'freight-wait-compact' -Name 'freight-wait-1024x768' -Replay 'freight-wait' -Resolution '1024x768'
        }
        if ($RavineLayout) {
            Start-VerifiedGame -Directory $release -Profile 'ravine-map-compact' -Name 'ravine-map-1024x768' -Replay 'ravine-map' -Resolution '1024x768'
        }
        if ($MarketWayfinding) {
            Start-VerifiedGame -Directory $release -Profile 'market-wayfinding-compact' -Name 'market-wayfinding-1024x768' -Replay 'market-wayfinding' -Resolution '1024x768'
        }
        if ($FishMarketOrders) {
            Start-VerifiedGame -Directory $release -Profile 'fish-market-orders-compact' -Name 'fish-market-orders-1024x768' -Replay 'fish-market-orders' -Resolution '1024x768'
        }
        if ($AmbienceTravel) {
            Start-VerifiedGame -Directory $release -Profile 'ambience-travel-compact' -Name 'ambience-travel-1024x768' -Replay 'ambience-travel' -Resolution '1024x768'
        }
        if ($EstateTerrain) {
            Start-VerifiedGame -Directory $release -Profile 'estate-terrain-compact' -Name 'estate-terrain-1024x768' -Replay 'estate-terrain' -Resolution '1024x768'
        }
        if ($CanalDoors) {
            Start-VerifiedGame -Directory $release -Profile 'irrigation-flow-compact' -Name 'irrigation-flow-1024x768' -Replay 'irrigation-flow' -Resolution '1024x768'
        }
        if ($RaidFeedback) {
            Start-VerifiedGame -Directory $release -Profile 'raid-feedback-compact' -Name 'raid-feedback-1024x768' -Replay 'raid-feedback' -Resolution '1024x768'
        }
        if ($PavilionEvening) {
            Start-VerifiedGame -Directory $release -Profile 'pavilion-stories-compact' -Name 'pavilion-stories-1024x768' -Replay 'pavilion-stories' -Resolution '1024x768'
        }
        if ($RouteGoals) {
            Start-VerifiedGame -Directory $release -Profile 'council-prep-compact' -Name 'council-prep-1024x768' -Replay 'council-prep' -Resolution '1024x768'
            Start-VerifiedGame -Directory $release -Profile 'ending-film-compact' -Name 'ending-film-1024x768' -Replay 'ending-film' -Resolution '1024x768'
        }
        if ($Rations) {
            Start-VerifiedGame -Directory $release -Profile 'night-rations-compact' -Name 'night-rations-1024x768' -Replay 'night-rations' -Resolution '1024x768'
        }
        if ($SouthRoad) {
            Start-VerifiedGame -Directory $release -Profile 'market-orders-compact' -Name 'market-orders-1024x768' -Replay 'market-orders' -Resolution '1024x768'
        }
        if ($Opening) {
            Start-VerifiedGame -Directory $release -Profile 'opening-compact' -Name 'opening-1024x768' -Replay 'estate-directions' -Resolution '1024x768'
            Start-VerifiedGame -Directory $release -Profile 'estate-progress-compact' -Name 'estate-progress-1024x768' -Replay 'estate-progress' -Resolution '1024x768'
            Start-VerifiedGame -Directory $release -Profile 'recruitment-compact' -Name 'recruitment-ledger-1024x768' -Replay 'recruitment-ledger' -Resolution '1024x768'
        }
        if ($FieldStroke) {
            Start-VerifiedGame -Directory $release -Profile 'field-stroke-compact' -Name 'field-stroke-1024x768' -Replay 'field-stroke' -Resolution '1024x768'
        }
    }
    if ($Soak) {
        Start-VerifiedGame -Directory $release -Profile 'soak' -Name 'soak' -Replay 'soak'
    }
    foreach ($file in $runtime) {
        if ((Get-FileHash -LiteralPath $file.Path).Hash -ne $file.Hash) {
            throw "The verifier modified a distributed file at $($file.Path)."
        }
    }
    $zip = Get-Item -LiteralPath $packagePath
    $manifest = @(
        "$($zip.Name) $($zip.Length) bytes",
        "ZIP SHA256 $((Get-FileHash -LiteralPath $packagePath).Hash)"
    )
    $manifest += $runtime | ForEach-Object { "$([IO.Path]::GetFileName($_.Path)) SHA256 $($_.Hash)" }
    $manifest | Set-Content -LiteralPath (Join-Path $evidence 'manifest.txt') -Encoding utf8
    Write-Host "Windows release checks passed. Evidence saved to $evidence"
} finally {
    $env:APPDATA = $originalAppData
    $tempRoot = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath([IO.Path]::GetTempPath()))
    $resolvedScratch = Get-Item -LiteralPath $scratch.FullName -Force
    if ($resolvedScratch.Parent.FullName -eq $tempRoot -and
        $resolvedScratch.Name -like 'fiefdom-smoke-release-*' -and
        -not ($resolvedScratch.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Remove-Item -LiteralPath $resolvedScratch.FullName -Recurse -Force
    }
}
