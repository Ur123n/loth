Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path -LiteralPath "$PSScriptRoot\..\..\..").Path
$godotExe='C:\1\Godot_v4.7.1-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godotExe)) { throw 'Godot executable missing' }
$scriptPath=Join-Path $projectRoot 'maps\leyton\tools\capture_gatehouse.gd'
if (-not (Test-Path -LiteralPath $scriptPath)) { throw 'Capture script missing' }
$existing=Get-CimInstance Win32_Process -Filter "Name='Godot_v4.7.1-stable_win64_console.exe'" | Where-Object { $_.CommandLine -like '*capture_gatehouse.gd*' }
if ($null -ne $existing) { throw 'Gatehouse capture already running; inspect its logs before retrying' }
$qaPath=Join-Path $projectRoot 'maps\leyton\qa'
$arguments=@('--path',('"'+$projectRoot+'"'),'--rendering-method','gl_compatibility','--position','-16000,-16000','--resolution','1280x720','--script','maps/leyton/tools/capture_gatehouse.gd')
$process=Start-Process -FilePath $godotExe -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $qaPath 'gatehouse_capture.log') -RedirectStandardError (Join-Path $qaPath 'gatehouse_capture.err.log') -PassThru
Write-Output "Gatehouse capture PID=$($process.Id)"
