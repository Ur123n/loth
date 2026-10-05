Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path -LiteralPath "$PSScriptRoot\..\..\..").Path
$godotExe='C:\1\Godot_v4.7.1-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godotExe)) { throw 'Godot missing' }
$existing=Get-CimInstance Win32_Process -Filter "Name='Godot_v4.7.1-stable_win64_console.exe'" | Where-Object { $_.CommandLine -like '*leyton_world_demo/tools/capture.gd*' }
if ($null -ne $existing) { throw 'World demo capture already running' }
$qa=Join-Path $projectRoot 'dev\leyton_world_demo\qa'
$argsList=@('--path',('"'+$projectRoot+'"'),'--rendering-method','gl_compatibility','--position','-16000,-16000','--resolution','1280x720','--script','dev/leyton_world_demo/tools/capture.gd')
$process=Start-Process -FilePath $godotExe -ArgumentList $argsList -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $qa 'capture.log') -RedirectStandardError (Join-Path $qa 'capture.err.log') -PassThru
Write-Output "World demo capture PID=$($process.Id)"
