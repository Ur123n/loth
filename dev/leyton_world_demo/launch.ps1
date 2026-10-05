Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$godotExe='C:\1\Godot_v4.7.1-stable_win64.exe'
if (-not (Test-Path -LiteralPath $godotExe)) { throw 'Godot executable missing' }
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'dev\leyton_world_demo\world_demo.tscn'))) { throw 'Demo scene missing' }
$argsList=@('--path',('"'+$projectRoot+'"'),'--rendering-method','gl_compatibility','--resolution','1280x720','res://dev/leyton_world_demo/world_demo.tscn')
# This launcher is explicitly for the user's visible, interactive review session.
Start-Process -FilePath $godotExe -ArgumentList $argsList -WorkingDirectory $projectRoot -WindowStyle Normal | Out-Null
