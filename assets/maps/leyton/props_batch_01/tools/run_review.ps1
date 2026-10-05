Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path -LiteralPath "$PSScriptRoot\..\..\..\..\..").Path
$godotExe='C:\1\Godot_v4.7.1-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godotExe)) { throw 'Godot missing' }
$existing=Get-CimInstance Win32_Process -Filter "Name='Godot_v4.7.1-stable_win64_console.exe'" | Where-Object { $_.CommandLine -like '*capture_review.gd*' }
if ($null -ne $existing) { throw 'Capture already running; inspect before retrying' }
$qaPath=Join-Path (Split-Path $PSScriptRoot -Parent) 'qa'
$argsList=@('--path',('"'+$projectRoot+'"'),'--rendering-method','gl_compatibility','--position','-16000,-16000','--resolution','1280x960','--script','assets/maps/leyton/props_batch_01/tools/capture_review.gd')
$process=Start-Process -FilePath $godotExe -ArgumentList $argsList -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $qaPath 'runtime.log') -RedirectStandardError (Join-Path $qaPath 'runtime.err.log') -PassThru
Write-Output "Props review PID=$($process.Id)"
