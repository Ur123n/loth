param(
    [string]$JsonPath = (Join-Path $PSScriptRoot 'leyton_graybox_layouts_v01.json'),
    [string]$OutputDirectory = $PSScriptRoot
)

Add-Type -AssemblyName System.Drawing

$data = Get-Content -Raw -Encoding UTF8 -LiteralPath $JsonPath | ConvertFrom-Json
$scale = [int]$data.preview_px_per_tile
$marginX = 24
$headerHeight = 58
$footerHeight = 42

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
}

function Color([string]$hex) {
    return [System.Drawing.ColorTranslator]::FromHtml($hex)
}

function Brush([string]$hex) {
    return [System.Drawing.SolidBrush]::new((Color $hex))
}

function Pen([string]$hex, [float]$width) {
    return [System.Drawing.Pen]::new((Color $hex), $width)
}

$palette = @{
    background = '#14181b'
    playfield = '#4c5152'
    grid_minor = '#677071'
    grid_major = '#8a9392'
    border = '#e1e5df'
    road_main = '#b49a72'
    road_secondary = '#9f8a69'
    road_lane = '#87765e'
    road_bridge = '#c1a77c'
    water = '#3e748c'
    water_candidate = '#5b99b4'
    wall = '#173f45'
    gate = '#b7a472'
    structure = '#3d3a39'
    civic = '#575c68'
    religious = '#665b70'
    military = '#505b61'
    utility = '#596869'
    landmark = '#d1b965'
    plaza = '#77746c'
    estate_yard = '#5b6358'
    noble = '#494443'
    slum = '#5c4843'
    hazard = '#6d4e45'
    market = '#635845'
    workshops = '#554c40'
    warehouse = '#45413d'
    workshop = '#53463e'
    lodging = '#4d4543'
    stable = '#514839'
    bridge = '#a78d63'
    field = '#696c42'
    orchard = '#4d6446'
    pasture = '#60704c'
    smallholding = '#665f3e'
    vegetable = '#536845'
    livestock = '#5f5741'
    beans = '#5a6740'
    lake = '#355f70'
    checkpoint = '#6b6255'
    caravan = '#64594b'
    farm = '#51483e'
    refugee = '#5c4a45'
    isolation = '#5f5350'
    labor = '#534b43'
    crematorium = '#3f3634'
    shack = '#433836'
    gatehouse = '#3a3d3d'
    water_gate = '#304a50'
    mill = '#4b443b'
    exit = '#a9d18e'
    text = '#f3f0e7'
    subtext = '#c4cfcb'
}

$fontTitle = [System.Drawing.Font]::new('Microsoft YaHei', 15, [System.Drawing.FontStyle]::Bold)
$fontSubtitle = [System.Drawing.Font]::new('Microsoft YaHei', 9)
$fontLabel = [System.Drawing.Font]::new('Microsoft YaHei', 8)
$fontTiny = [System.Drawing.Font]::new('Microsoft YaHei', 7)
$brushText = Brush $palette.text
$brushSubtext = Brush $palette.subtext
$penBorder = Pen $palette.border 2
$penMinor = Pen $palette.grid_minor 0.5
$penMajor = Pen $palette.grid_major 1
$penExit = Pen $palette.exit 4

$fileNames = @{
    M01S = 'M01_central_square_river_south_graybox_v01.png'
    M01N = 'M01_central_square_river_north_graybox_v01.png'
    M02 = 'M02_north_noble_graybox_v01.png'
    M03 = 'M03_south_slums_graybox_v01.png'
    M04 = 'M04_west_market_graybox_v01.png'
    M05 = 'M05_north_gate_graybox_v01.png'
    M06 = 'M06_south_gate_graybox_v01.png'
    M07 = 'M07_west_gate_graybox_v01.png'
    M08 = 'M08_east_gate_graybox_v01.png'
}

function Get-ElementColor([string]$kind, [string]$fallback) {
    if ($palette.ContainsKey($kind)) { return $palette[$kind] }
    return $fallback
}

function Draw-CenteredLabel($graphics, [string]$text, $font, $brush, [System.Drawing.RectangleF]$rect) {
    if ([string]::IsNullOrWhiteSpace($text)) { return }
    $format = [System.Drawing.StringFormat]::new()
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $format.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
    $graphics.DrawString($text, $font, $brush, $rect, $format)
    $format.Dispose()
}

function To-PixelRect($rect) {
    return [System.Drawing.RectangleF]::new(
        [float]($marginX + $rect[0] * $scale),
        [float]($headerHeight + $rect[1] * $scale),
        [float]($rect[2] * $scale),
        [float]($rect[3] * $scale)
    )
}

function Draw-Layout($layout) {
    $mapWidth = [int]$layout.size[0] * $scale
    $mapHeight = [int]$layout.size[1] * $scale
    $canvasWidth = $mapWidth + $marginX * 2
    $canvasHeight = $headerHeight + $mapHeight + $footerHeight
    $bitmap = [System.Drawing.Bitmap]::new($canvasWidth, $canvasHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.Clear((Color $palette.background))

    $graphics.DrawString("$($layout.id)  $($layout.name)", $fontTitle, $brushText, 18, 10)
    $statusText = "$($layout.size[0])x$($layout.size[1]) tiles | 1:8 | 6 px/tile | orthographic | $($layout.status)"
    $graphics.DrawString($statusText, $fontSubtitle, $brushSubtext, 20, 36)

    $playRect = [System.Drawing.RectangleF]::new($marginX, $headerHeight, $mapWidth, $mapHeight)
    $playBrush = Brush $palette.playfield
    $graphics.FillRectangle($playBrush, $playRect)
    $playBrush.Dispose()

    foreach ($zone in @($layout.zones)) {
        $rect = To-PixelRect $zone.rect
        $zoneBrush = Brush (Get-ElementColor $zone.kind $palette.structure)
        if ($zone.shape -eq 'ellipse') {
            $graphics.FillEllipse($zoneBrush, $rect)
        } else {
            $graphics.FillRectangle($zoneBrush, $rect)
        }
        Draw-CenteredLabel $graphics $zone.label $fontLabel $brushSubtext $rect
        $zoneBrush.Dispose()
    }

    foreach ($water in @($layout.water)) {
        $waterPen = Pen (Get-ElementColor $water.kind $palette.water) ([float]$water.width * $scale)
        if ($water.kind -match 'candidate') { $waterPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash }
        $points = @()
        foreach ($point in $water.points) {
            $points += [System.Drawing.PointF]::new(
                [float]($marginX + $point[0] * $scale),
                [float]($headerHeight + $point[1] * $scale)
            )
        }
        if ($points.Count -ge 2) { $graphics.DrawLines($waterPen, [System.Drawing.PointF[]]$points) }
        $waterPen.Dispose()
    }

    foreach ($road in @($layout.roads)) {
        $roadColor = switch ($road.kind) {
            'secondary' { $palette.road_secondary }
            'lane' { $palette.road_lane }
            'bridge_road' { $palette.road_bridge }
            default { $palette.road_main }
        }
        $roadBrush = Brush $roadColor
        if ($road.shape -eq 'polyline') {
            $roadPen = Pen $roadColor ([float]$road.width * $scale)
            $points = @()
            foreach ($point in $road.points) {
                $points += [System.Drawing.PointF]::new(
                    [float]($marginX + $point[0] * $scale),
                    [float]($headerHeight + $point[1] * $scale)
                )
            }
            if ($points.Count -ge 2) { $graphics.DrawLines($roadPen, [System.Drawing.PointF[]]$points) }
            $roadPen.Dispose()
        } else {
            $graphics.FillRectangle($roadBrush, (To-PixelRect $road.rect))
        }
        $roadBrush.Dispose()
    }

    if ($null -ne $layout.walls) {
        foreach ($wall in $layout.walls) {
            $wallBrush = Brush $palette.wall
            $graphics.FillRectangle($wallBrush, (To-PixelRect $wall.rect))
            $wallBrush.Dispose()
        }
    }

    foreach ($structure in @($layout.structures)) {
        $rect = To-PixelRect $structure.rect
        $structureBrush = Brush (Get-ElementColor $structure.kind $palette.structure)
        $graphics.FillRectangle($structureBrush, $rect)
        $structurePen = Pen '#9ca39e' 1
        $graphics.DrawRectangle($structurePen, $rect.X, $rect.Y, $rect.Width, $rect.Height)
        if ($rect.Width -ge 48 -and $rect.Height -ge 28) {
            Draw-CenteredLabel $graphics $structure.label $fontLabel $brushText $rect
        }
        $structurePen.Dispose()
        $structureBrush.Dispose()
    }

    # Grid is intentionally drawn over masses so tile alignment remains auditable.
    for ($x = 0; $x -le [int]$layout.size[0]; $x++) {
        $px = $marginX + $x * $scale
        $pen = if (($x % 8) -eq 0) { $penMajor } else { $penMinor }
        $graphics.DrawLine($pen, $px, $headerHeight, $px, $headerHeight + $mapHeight)
    }
    for ($y = 0; $y -le [int]$layout.size[1]; $y++) {
        $py = $headerHeight + $y * $scale
        $pen = if (($y % 8) -eq 0) { $penMajor } else { $penMinor }
        $graphics.DrawLine($pen, $marginX, $py, $marginX + $mapWidth, $py)
    }
    $graphics.DrawRectangle($penBorder, $playRect.X, $playRect.Y, $playRect.Width, $playRect.Height)

    $exitTexts = @()
    foreach ($exit in $layout.exits) {
        $edge = [string]$exit.edge
        $offset = [float]$exit.offset * $scale
        $band = [float]$exit.width * $scale
        switch ($edge) {
            'north' { $graphics.DrawLine($penExit, $marginX + $offset, $headerHeight, $marginX + $offset + $band, $headerHeight) }
            'south' { $graphics.DrawLine($penExit, $marginX + $offset, $headerHeight + $mapHeight, $marginX + $offset + $band, $headerHeight + $mapHeight) }
            'west' { $graphics.DrawLine($penExit, $marginX, $headerHeight + $offset, $marginX, $headerHeight + $offset + $band) }
            'east' { $graphics.DrawLine($penExit, $marginX + $mapWidth, $headerHeight + $offset, $marginX + $mapWidth, $headerHeight + $offset + $band) }
        }
        $exitTexts += "$edge@$($exit.offset)+$($exit.width) -> $($exit.to)"
    }
    $graphics.DrawString(($exitTexts -join '  |  '), $fontTiny, $brushSubtext, 20, $headerHeight + $mapHeight + 10)

    $fileName = $fileNames[$layout.id]
    $path = Join-Path $OutputDirectory $fileName
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    return $path
}

$rendered = @()
foreach ($layout in $data.layouts) {
    $rendered += Draw-Layout $layout
}

# Contact sheet preserves every image at native 1:8 scale. No cell image is resized.
$cellWidth = 640
$cellHeight = 650
$columns = 3
$rows = [Math]::Ceiling($rendered.Count / $columns)
$sheetWidth = $cellWidth * $columns
$sheetHeight = 70 + $cellHeight * $rows
$sheet = [System.Drawing.Bitmap]::new($sheetWidth, $sheetHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$sheetGraphics = [System.Drawing.Graphics]::FromImage($sheet)
$sheetGraphics.Clear((Color $palette.background))
$sheetGraphics.DrawString('LEYTON CITY GRAYBOX CONTACT SHEET v0.1', $fontTitle, $brushText, 24, 16)
$sheetGraphics.DrawString('All map playfields remain native 1:8 scale (6 px per tile). No perspective and no per-image resizing.', $fontSubtitle, $brushSubtext, 26, 44)

for ($i = 0; $i -lt $rendered.Count; $i++) {
    $image = [System.Drawing.Image]::FromFile($rendered[$i])
    $col = $i % $columns
    $row = [Math]::Floor($i / $columns)
    $x = $col * $cellWidth + [Math]::Floor(($cellWidth - $image.Width) / 2)
    $y = 70 + $row * $cellHeight + [Math]::Floor(($cellHeight - $image.Height) / 2)
    $sheetGraphics.DrawImageUnscaled($image, $x, $y)
    $image.Dispose()
}

$sheetPath = Join-Path $OutputDirectory 'leyton_graybox_contact_sheet_v01.png'
$sheet.Save($sheetPath, [System.Drawing.Imaging.ImageFormat]::Png)
$sheetGraphics.Dispose()
$sheet.Dispose()

foreach ($resource in @($fontTitle,$fontSubtitle,$fontLabel,$fontTiny,$brushText,$brushSubtext,$penBorder,$penMinor,$penMajor,$penExit)) {
    $resource.Dispose()
}

$rendered
$sheetPath
