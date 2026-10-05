Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$godotExe='C:\1\Godot_v4.7.1-stable_win64_console.exe'
$projectRoot='C:\游戏'
$qa=Join-Path $projectRoot 'maps\leyton\street_sample_v3\qa'
if (-not (Test-Path -LiteralPath $godotExe)) { throw 'Godot missing' }
$existing=Get-CimInstance Win32_Process -Filter "Name='Godot_v4.7.1-stable_win64_console.exe'" | Where-Object { $_.CommandLine -like '*street_sample_v3/check.gd*' }
if ($null -ne $existing) { throw 'Sample capture already running' }
$captureArgs=@('--path',('"'+$projectRoot+'"'),'--rendering-method','gl_compatibility','--position','-16000,-16000','--resolution','1280x900','--script','maps/leyton/street_sample_v3/check.gd')
$p=Start-Process -FilePath $godotExe -ArgumentList $captureArgs -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $qa 'capture.log') -RedirectStandardError (Join-Path $qa 'capture.err.log') -PassThru
Write-Output "Sample capture PID=$($p.Id)"
