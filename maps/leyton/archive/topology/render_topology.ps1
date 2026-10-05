param(
    [string]$JsonPath = (Join-Path $PSScriptRoot 'leyton_master_topology_v01.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot 'leyton_master_topology_v01.png')
)

Add-Type -AssemblyName System.Drawing

$data = Get-Content -Raw -Encoding UTF8 -LiteralPath $JsonPath | ConvertFrom-Json
$width = 2160
$height = 1800
$bitmap = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#10171a'))

function New-Brush([string]$color) {
    return [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($color))
}

function New-Pen([string]$color, [float]$penWidth) {
    return [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml($color), $penWidth)
}

$fontTitle = [System.Drawing.Font]::new('Microsoft YaHei', 22, [System.Drawing.FontStyle]::Bold)
$fontSubtitle = [System.Drawing.Font]::new('Microsoft YaHei', 11)
$fontMap = [System.Drawing.Font]::new('Microsoft YaHei', 14, [System.Drawing.FontStyle]::Bold)
$fontSmall = [System.Drawing.Font]::new('Microsoft YaHei', 9)
$brushTitle = New-Brush '#eef3ef'
$brushSubtitle = New-Brush '#aab8b5'
$brushText = New-Brush '#f5f0df'
$brushSmall = New-Brush '#d0d9d5'
$penMap = New-Pen '#dbe5e1' 2
$penGrid = New-Pen '#d8e0dd' 0.45
$penGrid.Color = [System.Drawing.Color]::FromArgb(35, $penGrid.Color)
$penConnect = New-Pen '#d6c7a4' 6
$penWorld = New-Pen '#8ea096' 5
$penWorld.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$penAbstract = New-Pen '#c29f68' 6
$penAbstract.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$penWater = New-Pen '#3e748c' 18
$penCandidate = New-Pen '#5d91a8' 12
$penCandidate.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$brushRoad = New-Brush '#a88b62'
$brushWall = New-Brush '#173f45'
$brushGate = New-Brush '#b7a472'
$brushBuilding = New-Brush '#493f3b'
$brushField = New-Brush '#676a3e'
$brushLake = New-Brush '#345f70'
$brushVoid = New-Brush '#10171a'
$brushSquare = New-Brush '#7f7868'
$brushNode = New-Brush '#d9c587'

$graphics.DrawString('莱顿城八区总拓扑 v0.1', $fontTitle, $brushTitle, 56, 36)
$graphics.DrawString('严格正交俯视 · 无透视/无近大远小 · 1 游戏瓦片 = 4 图像像素 · 地图矩形按格数等比绘制', $fontSubtitle, $brushSubtitle, 56, 74)

$mapById = @{}
foreach ($map in $data.maps) {
    $mapById[$map.id] = $map
}

function Get-Rect([string]$id) {
    $r = $mapById[$id].diagram_rect
    return [System.Drawing.RectangleF]::new([float]$r[0], [float]$r[1], [float]$r[2], [float]$r[3])
}

function Draw-Line([System.Drawing.Pen]$pen, [float]$x1, [float]$y1, [float]$x2, [float]$y2) {
    $graphics.DrawLine($pen, $x1, $y1, $x2, $y2)
}

# Fixed orthogonal connections.
Draw-Line $penWorld 1232 0 1232 40
Draw-Line $penWorld 1232 328 1232 360
Draw-Line $penWorld 1232 680 1232 720
Draw-Line $penWorld 1232 1040 1232 1072
Draw-Line $penWorld 1232 1424 1232 1456
Draw-Line $penWorld 1232 1744 1232 1790
Draw-Line $penConnect 592 880 624 880
Draw-Line $penConnect 1008 880 1040 880
Draw-Line $penAbstract 1424 880 1664 880
Draw-Line $penWorld 64 880 208 880
Draw-Line $penWorld 2048 864 2120 864
$graphics.DrawLines($penCandidate, [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(592,934), [System.Drawing.PointF]::new(608,934),
    [System.Drawing.PointF]::new(608,950), [System.Drawing.PointF]::new(624,950)
))
$graphics.DrawLines($penCandidate, [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(1008,950), [System.Drawing.PointF]::new(1024,950),
    [System.Drawing.PointF]::new(1024,986), [System.Drawing.PointF]::new(1040,986)
))
$graphics.DrawLines($penCandidate, [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(1424,986), [System.Drawing.PointF]::new(1544,986),
    [System.Drawing.PointF]::new(1544,944), [System.Drawing.PointF]::new(1664,944)
))

$mapColors = @{
    M01 = '#505962'; M02 = '#4d574d'; M03 = '#5a443f'; M04 = '#5c513f'
    M05 = '#465049'; M06 = '#4d5043'; M07 = '#48514a'; M08 = '#4b5548'
}

function Draw-MapBase([string]$id) {
    $map = $mapById[$id]
    $rect = Get-Rect $id
    $brush = New-Brush $mapColors[$id]
    $graphics.FillRectangle($brush, $rect)
    $brush.Dispose()
    for ($x = [int]$rect.X; $x -le [int]$rect.Right; $x += 32) {
        Draw-Line $penGrid $x $rect.Y $x $rect.Bottom
    }
    for ($y = [int]$rect.Y; $y -le [int]$rect.Bottom; $y += 32) {
        Draw-Line $penGrid $rect.X $y $rect.Right $y
    }
    $graphics.DrawRectangle($penMap, $rect.X, $rect.Y, $rect.Width, $rect.Height)
}

foreach ($id in @('M05','M02','M07','M04','M01','M08','M03','M06')) { Draw-MapBase $id }

# M05 north gate and fields.
$graphics.FillRectangle($brushField, 1080, 82, 116, 72)
$graphics.FillRectangle($brushField, 1268, 78, 112, 78)
$graphics.FillRectangle($brushField, 1092, 182, 104, 78)
$graphics.FillRectangle($brushField, 1270, 184, 106, 72)
$graphics.FillRectangle($brushRoad, 1220, 40, 24, 288)
$graphics.FillRectangle($brushWall, 1056, 308, 352, 20)
$graphics.FillRectangle($brushGate, 1202, 286, 60, 42)
$graphics.FillRectangle($brushVoid, 1222, 304, 20, 24)

# M02 noble district.
$graphics.FillRectangle($brushRoad, 1220, 360, 24, 320)
$graphics.FillRectangle($brushRoad, 1056, 510, 352, 20)
foreach ($r in @(@(1084,414,102,70),@(1278,404,98,86),@(1088,564,110,76),@(1278,568,92,62))) {
    $graphics.FillRectangle($brushBuilding, $r[0], $r[1], $r[2], $r[3])
}

# M07 west gate, lake and water route.
$graphics.FillEllipse($brushLake, 226, 760, 208, 170)
$graphics.DrawLine($penWater, 292, 856, 484, 934)
$graphics.DrawLine($penWater, 484, 934, 592, 934)
$graphics.FillRectangle($brushRoad, 208, 868, 384, 24)
$graphics.FillRectangle($brushField, 250, 950, 110, 64)
$graphics.FillRectangle($brushField, 382, 960, 104, 56)
$graphics.FillRectangle($brushWall, 572, 720, 20, 320)
$graphics.FillRectangle($brushGate, 552, 850, 40, 60)
$graphics.FillRectangle($brushVoid, 568, 870, 24, 20)
$graphics.FillRectangle($brushGate, 558, 938, 34, 48)

# M04 commercial district.
$graphics.FillRectangle($brushRoad, 624, 868, 384, 24)
$graphics.DrawLine($penWater, 624, 950, 1008, 950)
$graphics.FillRectangle($brushGate, 798, 932, 36, 36)
foreach ($r in @(@(652,772,90,62),@(766,762,88,72),@(880,770,94,64),@(648,978,96,42),@(874,978,106,42))) {
    $graphics.FillRectangle($brushBuilding, $r[0], $r[1], $r[2], $r[3])
}

# M01 central square and provisional south river route.
$graphics.FillRectangle($brushRoad, 1220, 720, 24, 320)
$graphics.FillRectangle($brushRoad, 1040, 868, 384, 24)
$graphics.FillRectangle($brushSquare, 1160, 812, 144, 136)
$graphics.FillEllipse($brushNode, 1212, 860, 40, 40)
$graphics.DrawLines($penCandidate, [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(1040,986), [System.Drawing.PointF]::new(1126,986),
    [System.Drawing.PointF]::new(1146,1006), [System.Drawing.PointF]::new(1318,1006),
    [System.Drawing.PointF]::new(1338,986), [System.Drawing.PointF]::new(1424,986)
))
foreach ($r in @(@(1070,758,94,50),@(1306,756,88,54),@(1070,958,68,44))) {
    $graphics.FillRectangle($brushBuilding, $r[0], $r[1], $r[2], $r[3])
}

# M08 east gate and fields.
$graphics.FillRectangle($brushRoad, 1664, 868, 384, 24)
$graphics.DrawLine($penWater, 1664, 944, 2048, 944)
$graphics.FillRectangle($brushField, 1726, 762, 110, 72)
$graphics.FillRectangle($brushField, 1870, 758, 126, 78)
$graphics.FillRectangle($brushField, 1730, 958, 108, 34)
$graphics.FillRectangle($brushWall, 1664, 720, 20, 288)
$graphics.FillRectangle($brushGate, 1664, 850, 40, 60)
$graphics.FillRectangle($brushVoid, 1664, 870, 24, 20)
$graphics.FillRectangle($brushGate, 1664, 924, 34, 48)
$graphics.FillEllipse($brushBuilding, 1924, 900, 60, 60)

# M03 dense slum, deliberately irregular but still orthographic.
$graphics.FillPolygon($brushRoad, [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(1220,1072), [System.Drawing.PointF]::new(1244,1072),
    [System.Drawing.PointF]::new(1244,1154), [System.Drawing.PointF]::new(1264,1190),
    [System.Drawing.PointF]::new(1264,1274), [System.Drawing.PointF]::new(1234,1318),
    [System.Drawing.PointF]::new(1234,1424), [System.Drawing.PointF]::new(1214,1424),
    [System.Drawing.PointF]::new(1214,1310), [System.Drawing.PointF]::new(1234,1268),
    [System.Drawing.PointF]::new(1234,1198), [System.Drawing.PointF]::new(1220,1160)
))
foreach ($r in @(
    @(1060,1118,62,42),@(1128,1108,70,54),@(1268,1110,58,48),@(1334,1120,68,42),
    @(1066,1180,76,44),@(1152,1178,50,54),@(1278,1184,74,42),@(1358,1176,46,60),
    @(1058,1250,56,58),@(1122,1242,80,52),@(1272,1246,54,48),@(1336,1242,72,58),
    @(1066,1330,60,54),@(1136,1318,66,70)
)) { $graphics.FillRectangle($brushBuilding, $r[0], $r[1], $r[2], $r[3]) }
$graphics.FillRectangle($brushBuilding, 1284, 1318, 118, 82)
$graphics.FillRectangle($brushWall, 1040, 1404, 384, 20)

# M06 south gate and smallholdings.
$graphics.FillRectangle($brushWall, 1056, 1456, 352, 20)
$graphics.FillRectangle($brushGate, 1202, 1456, 60, 42)
$graphics.FillRectangle($brushVoid, 1222, 1456, 20, 24)
$graphics.FillRectangle($brushRoad, 1220, 1456, 24, 288)
foreach ($r in @(@(1080,1528,118,76),@(1268,1524,116,80),@(1082,1632,116,82),@(1268,1636,116,78))) {
    $graphics.FillRectangle($brushField, $r[0], $r[1], $r[2], $r[3])
}

# Map titles are drawn last for readability.
foreach ($map in $data.maps) {
    $r = $map.diagram_rect
    $x = [float]$r[0] + 12
    $y = [float]$r[1] + 8
    if ($map.id -eq 'M06') { $y += 32 }
    if ($map.id -eq 'M08') { $x += 36 }
    $graphics.DrawString("$($map.id) $($map.name)", $fontMap, $brushText, $x, $y)
    $graphics.DrawString("$($map.grid_size[0])×$($map.grid_size[1])格", $fontSmall, $brushSmall, $x, $y + 25)
}

$graphics.DrawString('太阳神像', $fontSmall, $brushText, 1201, 905)
$graphics.DrawString('主焚尸场', $fontSmall, $brushText, 1300, 1352)
$graphics.DrawString('大型灌溉湖', $fontSmall, $brushText, 250, 824)
$graphics.DrawString('抽象普通住宅区路程', $fontSubtitle, $brushText, 1470, 848)
$graphics.DrawString('河道南绕线（已冻结）', $fontSmall, $brushSmall, 1156, 1012)
$graphics.DrawString('西部煤铁产区/商路', $fontSmall, $brushSmall, 68, 856)
$graphics.DrawString('东部驿道', $fontSmall, $brushSmall, 2048, 840)
$graphics.DrawString('北方世界道路', $fontSmall, $brushSmall, 1248, 8)
$graphics.DrawString('南方世界道路', $fontSmall, $brushSmall, 1248, 1768)

# Scale legend.
$legendBrush = New-Brush '#172126'
$legendPen = New-Pen '#39484c' 1
$graphics.FillRectangle($legendBrush, 56, 112, 560, 176)
$graphics.DrawRectangle($legendPen, 56, 112, 560, 176)
$graphics.DrawString('图例与比例校验', $fontSubtitle, $brushText, 74, 126)
$graphics.DrawRectangle($penMap, 74, 156, 48, 48)
for ($x = 78; $x -lt 122; $x += 4) { Draw-Line $penGrid $x 156 $x 204 }
for ($y = 160; $y -lt 204; $y += 4) { Draw-Line $penGrid 74 $y 122 $y }
$graphics.DrawString('12×12游戏格；每格固定4×4图像像素', $fontSmall, $brushSmall, 138, 168)
$graphics.FillRectangle($brushRoad, 74, 224, 54, 14)
$graphics.DrawString('道路', $fontSmall, $brushSmall, 138, 223)
$graphics.FillRectangle($brushWall, 220, 224, 54, 14)
$graphics.DrawString('深青石城墙', $fontSmall, $brushSmall, 284, 223)
$graphics.DrawLine($penWater, 430, 231, 484, 231)
$graphics.DrawString('水系', $fontSmall, $brushSmall, 494, 223)
$graphics.DrawString('本图为固定比例拓扑；内部建筑仅表示功能占位，禁止从视觉截图反推最终坐标。', $fontSubtitle, $brushSubtitle, 56, 1760)

$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}
$bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)

$graphics.Dispose()
$bitmap.Dispose()
foreach ($resource in @(
    $fontTitle,$fontSubtitle,$fontMap,$fontSmall,$brushTitle,$brushSubtitle,$brushText,$brushSmall,
    $penMap,$penGrid,$penConnect,$penWorld,$penAbstract,$penWater,$penCandidate,$brushRoad,$brushWall,
    $brushGate,$brushBuilding,$brushField,$brushLake,$brushVoid,$brushSquare,$brushNode,$legendBrush,$legendPen
)) { $resource.Dispose() }

Write-Output $OutputPath
