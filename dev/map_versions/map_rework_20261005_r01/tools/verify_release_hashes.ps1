Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $taskRoot '..\..\..')).Path
$baseline = Get-Content -LiteralPath (Join-Path $taskRoot 'iserra\baseline.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$release = Get-Content -LiteralPath (Join-Path $taskRoot 'release_manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$failures = [Collections.Generic.List[string]]::new()
$unchanged = 0
$published = 0
foreach ($entry in $baseline.file_hashes.PSObject.Properties) {
    $relative = $entry.Name.Replace('\', '/')
    $active = $release.active_hashes.PSObject.Properties[$relative]
    $expected = if ($null -eq $active) { [string] $entry.Value } else { [string] $active.Value }
    $sourcePath = Join-Path $projectRoot $relative.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { $failures.Add("Missing: $relative"); continue }
    $actual = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    if ($actual -ine $expected) { $failures.Add("Changed: $relative") }
    if ($null -eq $active) { $unchanged++ } else { $published++ }
}
foreach ($entry in $release.asset_hashes.PSObject.Properties) {
    $sourcePath = Join-Path $projectRoot $entry.Name.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { $failures.Add("Missing asset: $($entry.Name)"); continue }
    $actual = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    if ($actual -ine [string] $entry.Value) { $failures.Add("Changed asset: $($entry.Name)") }
}
if ($unchanged -ne [int] $release.unchanged_baseline_files -or $published -ne 2) {
    $failures.Add("Unexpected baseline partition: unchanged=$unchanged published=$published")
}
$assetCount = @($release.asset_hashes.PSObject.Properties).Count
Write-Output "RELEASE_HASHES unchanged=$unchanged published=$published assets=$assetCount failed=$($failures.Count)"
$failures | ForEach-Object { Write-Output $_ }
if ($failures.Count -gt 0) { exit 1 }
