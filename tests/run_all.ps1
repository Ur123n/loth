param(
    [string]$Godot = "",
    [string]$Python = "",
    [switch]$Import
)

$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Godot)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
        $Godot = $env:GODOT_BIN
    } elseif (Test-Path -LiteralPath 'C:\1\Godot_v4.7.1-stable_win64_console.exe') {
        $Godot = 'C:\1\Godot_v4.7.1-stable_win64_console.exe'
    } else {
        $Godot = 'godot'
    }
}
if ([string]::IsNullOrWhiteSpace($Python)) {
    $Python = if (-not [string]::IsNullOrWhiteSpace($env:PYTHON_BIN)) { $env:PYTHON_BIN } else { 'python' }
}

$failures = [System.Collections.Generic.List[string]]::new()

function Invoke-GodotStep {
    param([string]$Name, [string[]]$Arguments)
    Write-Output "===== $Name ====="
    $output = @(& $Godot @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Output $_ }
    if ($exitCode -ne 0) {
        $script:failures.Add("$Name (exit=$exitCode)")
    }
}

if ($Import) {
    Invoke-GodotStep -Name 'Godot import' -Arguments @('--headless', '--path', $projectRoot, '--import')
}

$testFiles = Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File -Filter 'test_*.gd' | Sort-Object FullName
foreach ($testFile in $testFiles) {
    $relative = $testFile.FullName.Substring($projectRoot.Length) -replace '^[\\/]+', ''
    Invoke-GodotStep -Name $relative -Arguments @('--headless', '--path', $projectRoot, '--script', $testFile.FullName)
}

Write-Output '===== Story data validator ====='
$storyOutput = @(& $Python '-X' 'utf8' (Join-Path $projectRoot '编辑器\剧情检查.py') 2>&1)
$storyExit = $LASTEXITCODE
$storyOutput | ForEach-Object { Write-Output $_ }
if ($storyExit -ne 0) {
    $failures.Add("Story data validator (exit=$storyExit)")
}

Write-Output '===== JSON syntax ====='
$jsonFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'content') -Recurse -File -Filter '*.json'
foreach ($jsonFile in $jsonFiles) {
    try {
        $null = Get-Content -LiteralPath $jsonFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        $failures.Add("Invalid JSON: $($jsonFile.FullName): $($_.Exception.Message)")
    }
}
Write-Output "JSON files checked: $($jsonFiles.Count)"

Invoke-GodotStep -Name 'Main scene smoke test' -Arguments @('--headless', '--path', $projectRoot, '--quit-after', '120')
Invoke-GodotStep -Name 'Battle scene smoke test' -Arguments @('--headless', '--path', $projectRoot, '--quit-after', '5', 'res://world/encounters/BattleMap.tscn')

Write-Output "===== SUMMARY: tests=$($testFiles.Count) failures=$($failures.Count) ====="
foreach ($failure in $failures) {
    Write-Output "FAIL  $failure"
}
exit $(if ($failures.Count -eq 0) { 0 } else { 1 })
