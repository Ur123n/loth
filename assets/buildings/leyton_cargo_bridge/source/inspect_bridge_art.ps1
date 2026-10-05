param(
    [string]$ProjectRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..\..\..").Path
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$sourcePath = Join-Path $ProjectRoot 'assets\buildings\leyton_cargo_bridge\source\concept_v2.png'
$reportPath = Join-Path $ProjectRoot 'maps\leyton\qa\bridge_concept_v2.json'
$image = [System.Drawing.Bitmap]::new($sourcePath)
try {
    $left = $image.Width
    $top = $image.Height
    $right = -1
    $bottom = -1
    $transparent = 0
    $partial = 0
    $opaque = 0
    for ($y = 0; $y -lt $image.Height; $y++) {
        for ($x = 0; $x -lt $image.Width; $x++) {
            $alpha = $image.GetPixel($x, $y).A
            if ($alpha -eq 0) { $transparent++ }
            elseif ($alpha -eq 255) { $opaque++ }
            else { $partial++ }
            if ($alpha -ge 128) {
                $left = [Math]::Min($left, $x)
                $top = [Math]::Min($top, $y)
                $right = [Math]::Max($right, $x)
                $bottom = [Math]::Max($bottom, $y)
            }
        }
    }
    $report = [ordered]@{
        source = 'assets/buildings/leyton_cargo_bridge/source/concept_v2.png'
        sha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        size_px = @($image.Width, $image.Height)
        required_canvas_px = @(672, 624)
        native_canvas_matches = ($image.Width -eq 672 -and $image.Height -eq 624)
        alpha = [ordered]@{ transparent = $transparent; partial = $partial; opaque = $opaque }
        alpha_128_bounds_inclusive = @($left, $top, $right, $bottom)
        runtime_eligible = $false
        status = 'concept_only_pending_registration_and_layers'
        limitations = @(
            'Alpha bounds describe pixels only; they do not define collision.',
            'Native canvas mismatch requires registered export and visual inspection.',
            'North apron improved visually; exact parapet endpoints are not certified.',
            'Deck/rail layer separation and actor occlusion are not yet verified.'
        )
    }
    $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding UTF8
    $report | ConvertTo-Json -Depth 5
}
finally {
    $image.Dispose()
}
