Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $taskRoot '..\..\..')).Path
$baselinePath = Join-Path $taskRoot 'iserra\baseline.json'
$baseline = Get-Content -LiteralPath $baselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
$failures = [Collections.Generic.List[string]]::new()
$checked = 0
foreach ($entry in $baseline.file_hashes.PSObject.Properties) {
    $relative = $entry.Name.Replace('/', '\')
    $sourcePath = Join-Path $projectRoot $relative
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        $failures.Add("Missing: $relative")
        continue
    }
    $actual = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    if ($actual -ine [string] $entry.Value) { $failures.Add("Changed: $relative") }
    $checked++
}
Write-Output "ACTIVE_HASHES checked=$checked failed=$($failures.Count)"
$failures | ForEach-Object { Write-Output $_ }
if ($failures.Count -gt 0) { exit 1 }
