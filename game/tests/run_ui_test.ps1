# Starts a server and two full copies of the game that host/join a room through the real screens
# and play on their own. Both must end with the same game fingerprint.
param([string]$Url = "ws://127.0.0.1:8080", [int]$LocalServer = 1, [int]$StopAt = 300, [string]$Shot = "")
$godot = "C:\Users\SaTz\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
$proj = "C:\Users\SaTz\Dhayam\game"
$tmp = Join-Path $env:TEMP "dhayam-uitest"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Remove-Item "$tmp\*" -Force -ErrorAction SilentlyContinue
$server = $null
if ($LocalServer -eq 1) {
  $server = Start-Process -FilePath $godot -ArgumentList @("--headless","--path",$proj,"res://server.tscn","--","--server") -RedirectStandardOutput "$tmp\server.out" -RedirectStandardError "$tmp\server.err" -PassThru -WindowStyle Hidden
  Start-Sleep -Seconds 3
}
function Start-Game($name, $auto) {
  $env:DHAYAM_SKIP_INTRO = "1"; $env:DHAYAM_AUTO = $auto; $env:DHAYAM_NAME = $name
  $env:DHAYAM_TOKEN = "tok-$name"; $env:DHAYAM_URL = $Url; $env:DHAYAM_CODEFILE = "$tmp\code.txt"
  $env:DHAYAM_PLAYERS = "2"; $env:DHAYAM_AUTOPLAY = "1"; $env:DHAYAM_STOP_AT = "$StopAt"
  return Start-Process -FilePath $godot -ArgumentList @("--headless","--path",$proj) -RedirectStandardOutput "$tmp\$name.out" -RedirectStandardError "$tmp\$name.err" -PassThru -WindowStyle Hidden
}
$procs = @((Start-Game "Host" "host"), (Start-Game "Guest" "guest"))
Remove-Item Env:\DHAYAM_SKIP_INTRO, Env:\DHAYAM_AUTO, Env:\DHAYAM_NAME, Env:\DHAYAM_TOKEN, Env:\DHAYAM_URL, Env:\DHAYAM_CODEFILE, Env:\DHAYAM_PLAYERS, Env:\DHAYAM_AUTOPLAY, Env:\DHAYAM_STOP_AT
$procs | Wait-Process -Timeout 150 -ErrorAction SilentlyContinue
foreach ($n in "Host","Guest") {
  "---- $n ----"
  Get-Content "$tmp\$n.out" | Where-Object { $_ -match "RESULT|ERROR|SCRIPT" }
  Get-Content "$tmp\$n.err" -ErrorAction SilentlyContinue | Where-Object { $_ -match "SCRIPT ERROR|Invalid|Parse" } | Select-Object -First 5
}
if ($server) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
$procs | ForEach-Object { if (-not $_.HasExited) { Stop-Process -Id $_.Id -Force; "(a game window had to be stopped: it did not finish)" } }
