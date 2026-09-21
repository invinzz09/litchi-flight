param(
  [Parameter(Mandatory=$true)][string]$TaskId,   # uuid задачи (из task.txt: id=...)
  [Parameter(Mandatory=$true)][string]$Text,     # текст сообщения в чат задачи
  [string]$KeyFile = ""
)
# Отправка сообщения в чат задачи YouGile. ВЫЗЫВАТЬ ТОЛЬКО ПОСЛЕ ЯВНОГО "ДА" ПОЛЬЗОВАТЕЛЯ НА КОНКРЕТНЫЙ ТЕКСТ.
$ErrorActionPreference = 'Stop'
if (-not $KeyFile) {
  foreach ($c in @(".\yougile_key.txt", "$env:USERPROFILE\.claude\yougile_key.txt")) { if (Test-Path $c) { $KeyFile = $c; break } }
}
if (-not $KeyFile -or -not (Test-Path $KeyFile)) { throw "Не найден yougile_key.txt" }
$key = (Get-Content -LiteralPath $KeyFile -Raw).Trim()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$body = @{ text = $Text } | ConvertTo-Json -Compress
$r = Invoke-RestMethod -Uri "https://ru.yougile.com/api-v2/chats/$TaskId/messages" -Method Post -Headers @{ Authorization = "Bearer $key" } -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 60
$r | ConvertTo-Json -Compress
