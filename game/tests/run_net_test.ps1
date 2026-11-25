# Runs a real server and three scripted players on this PC, then compares their game states.
# Usage:  powershell -File tests\run_net_test.ps1 [-Url ws://127.0.0.1:8080] [-StartServer] [-DropAt 150]
param(
  [string]$Url = "ws://127.0.0.1:8080",
  [int]$LocalServer = 1,
  [int]$Target = 400,
  [int]$DropAt = -1
)
$godot = "C:\Users\SaTz\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
$proj = "C:\Users\SaTz\Dhayam\game"
$tmp = Join-Path $env:TEMP "dhayam-nettest"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Remove-Item "$tmp\*" -Force -ErrorAction SilentlyContinue
$codefile = "$tmp\code.txt"

$server = $null
if ($LocalServer -eq 1) {
  $server = Start-Process -FilePath $godot -ArgumentList @("--headless","--path",$proj,"res://server.tscn","--","--server") -RedirectStandardOutput "$tmp\server.out" -RedirectStandardError "$tmp\server.err" -PassThru -WindowStyle Hidden
  Start-Sleep -Seconds 3
}
function Start-Client($name, $role, $extra) {
  $clientArgs = @("--headless","--path",$proj,"res://tests/net_client.tscn","--","--role=$role","--url=$Url","--codefile=$codefile","--players=3","--target=$Target","--name=$name") + $extra
  return Start-Process -FilePath $godot -ArgumentList $clientArgs -RedirectStandardOutput "$tmp\$name.out" -RedirectStandardError "$tmp\$name.err" -PassThru -WindowStyle Hidden
}
$procs = @()
$procs += Start-Client "Host" "host" @()
$procs += Start-Client "Guest1" "guest" @()
$dropArg = @(); if ($DropAt -gt 0) { $dropArg = @("--dropat=$DropAt") }
$procs += Start-Client "Guest2" "guest" $dropArg
$procs | Wait-Process -Timeout 120 -ErrorAction SilentlyContinue
foreach ($n in "Host","Guest1","Guest2") {
  "---- $n ----"
  Get-Content "$tmp\$n.out" | Where-Object { $_ -match "RESULT|ERROR|lobby|started|drop|reconnect|TIMEOUT|failed|CHAT" }
}
if ($server) { "---- server log ----"; Get-Content "$tmp\server.out" | Select-Object -Last 8; Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
$procs | ForEach-Object { if (-not $_.HasExited) { Stop-Process -Id $_.Id -Force } }
