Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$godotExe = 'C:\1\Godot_v4.7.1-stable_win64_console.exe'
$projectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$qaPath = Join-Path $projectRoot 'maps\leyton\qa'
$checks = [System.Collections.Generic.List[string]]::new()
$checks.Add('tests/map/test_leyton.gd')
$checks.Add('tests/map/test_leyton_bridge.gd')
$checks.Add('tests/map/test_leyton_surface.gd')
$checks.Add('tests/map/test_godot_map_pipeline.gd')
$checks.Add('tests/map/test_building_pipeline.gd')
$checks.Add('tests/map/test_map_pipeline_phase_one.gd')
$checks.Add('tests/dev/test_script_compile.gd')
foreach ($check in $checks) {
    $logPath = Join-Path $qaPath (([IO.Path]::GetFileNameWithoutExtension($check)) + '.log')
    & $godotExe --headless --path $projectRoot --script $check 2>&1 | Set-Content -LiteralPath $logPath -Encoding UTF8
    $resultCode = $LASTEXITCODE
    Get-Content -LiteralPath $logPath -Encoding UTF8 | Select-Object -Last 3
    if ($resultCode -ne 0) { throw "Check failed: $check ($resultCode)" }
}
