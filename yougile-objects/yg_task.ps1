param(
  [Parameter(Mandatory=$true)][string]$Task,   # ссылка на задачу, PRE-2465, ID-18612 или uuid
  [string]$OutDir = "YouGile",                  # куда сложить дамп и вложения (относительно текущей папки)
  [string]$KeyFile = "",                        # файл с ключом API; по умолчанию ищется yougile_key.txt
  [switch]$NoFiles                              # не скачивать вложения
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$utf8 = New-Object Text.UTF8Encoding($false)

# --- ключ ---
if (-not $KeyFile) {
  foreach ($c in @(".\yougile_key.txt", "$env:USERPROFILE\.claude\yougile_key.txt")) { if (Test-Path $c) { $KeyFile = $c; break } }
}
if (-not $KeyFile -or -not (Test-Path $KeyFile)) { throw "Не найден файл с ключом YouGile (yougile_key.txt в папке проекта или в %USERPROFILE%\.claude\). См. УСТАНОВКА.md" }
$key = (Get-Content -LiteralPath $KeyFile -Raw).Trim()
$H = @{ Authorization = "Bearer $key" }
$api = "https://ru.yougile.com/api-v2"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-Json($url) { Invoke-RestMethod -Uri $url -Headers $H -Method Get -TimeoutSec 120 }

# --- разбор идентификатора ---
$ident = $Task.Trim()
if ($ident -match '#([A-Za-z]+-\d+)\s*$') { $ident = $Matches[1] }
elseif ($ident -match '#([0-9a-f-]{36})') { $ident = $Matches[1] }

$tk = $null
if ($ident -match '^[0-9a-f-]{36}$') {
  $tk = Get-Json "$api/tasks/$ident"
} else {
  # PRE-2465 / ID-18612: листаем список задач (новые идут в начале)
  $offset = 0
  while (-not $tk) {
    $page = Get-Json "$api/task-list?limit=1000&offset=$offset&includeDeleted=false"
    $hit = $page.content | Where-Object { $_.idTaskProject -eq $ident -or $_.idTaskCommon -eq $ident } | Select-Object -First 1
    if ($hit) { $tk = Get-Json "$api/tasks/$($hit.id)" }
    elseif (-not $page.paging.next) { break }
    else { $offset += 1000 }
  }
  if (-not $tk) { throw "Задача $ident не найдена" }
}

# --- пользователи, для имён в чате ---
$um = @{}
try { (Get-Json "$api/users?limit=1000").content | ForEach-Object { $um[$_.id] = $_.realName } } catch {}

# --- чат ---
$msgs = Get-Json "$api/chats/$($tk.id)/messages?limit=1000"

# --- вывод ---
$tag = if ($tk.idTaskProject) { $tk.idTaskProject } else { $tk.idTaskCommon }
$dir = Join-Path $OutDir $tag
New-Item -ItemType Directory -Force -Path $dir | Out-Null

$lines = @()
$lines += "TASK $($tk.idTaskProject) ($($tk.idTaskCommon)) id=$($tk.id)"
$lines += "TITLE: $($tk.title)"
$lines += "CREATED: " + [DateTimeOffset]::FromUnixTimeMilliseconds($tk.timestamp).ToLocalTime().ToString('yyyy-MM-dd HH:mm')
$lines += "ASSIGNED: " + (($tk.assigned | ForEach-Object { if ($um[$_]) { $um[$_] } else { $_ } }) -join ', ')
$desc = $tk.description
if ($desc) { $desc = (($desc -replace '<br\s*/?>', "`n") -replace '</p>', "`n") -replace '<[^>]+>', ' ' }
$lines += "DESCRIPTION:"; $lines += $desc; $lines += ""
$lines += "=== CHAT ($($msgs.paging.count) messages) ==="
$files = @()
foreach ($x in $msgs.content) {
  $who = if ($um[$x.fromUserId]) { $um[$x.fromUserId] } else { $x.fromUserId }
  $txt = $x.text
  # вложения: /root/#file:/user-data/<id>/<urlencoded name>
  $fm = [regex]::Matches($txt, '/user-data/([0-9a-f-]{36})/([^\s"<]+)')
  foreach ($f in $fm) {
    $name = [Uri]::UnescapeDataString([Uri]::UnescapeDataString($f.Groups[2].Value)) -replace '\?.*$', ''
    $files += [pscustomobject]@{ id = $f.Groups[1].Value; raw = $f.Groups[2].Value; name = $name }
    $txt = $txt.Replace($f.Value, "[файл: $name]")
  }
  $txt = ((($txt -replace '<br\s*/?>', ' | ') -replace '<[^>]+>', ' ') -replace '\s+', ' ').Trim()
  $when = ''
  if ($x.timestamp -gt 0) { $when = [DateTimeOffset]::FromUnixTimeMilliseconds($x.timestamp).ToLocalTime().ToString('yyyy-MM-dd HH:mm') }
  $lines += "[$when] ${who}: $txt"
}
$lines += ""
$lines += "=== FILES ($($files.Count)) ==="
$files | ForEach-Object { $lines += "  " + $_.name }
$dump = Join-Path $dir "task.txt"
[IO.File]::WriteAllLines($dump, $lines, $utf8)
$tk | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $dir "task.json") -Encoding UTF8

# --- вложения ---
if (-not $NoFiles -and $files.Count -gt 0) {
  $fdir = Join-Path $dir "files"; New-Item -ItemType Directory -Force -Path $fdir | Out-Null
  foreach ($f in $files) {
    $safe = ($f.name -replace '[\\/:*?"<>|]', '_')
    $dst = Join-Path $fdir $safe
    if (Test-Path $dst) { continue }
    try {
      Invoke-WebRequest -Uri "https://ru.yougile.com/user-data/$($f.id)/$($f.raw)" -Headers $H -OutFile $dst -TimeoutSec 600
      # архивы распаковать, если есть 7-Zip
      $z = "C:\Program Files\7-Zip\7z.exe"
      if ((Test-Path $z) -and ($safe -match '\.(7z|rar|zip)$')) {
        & $z x -y "-o$(Join-Path $fdir ([IO.Path]::GetFileNameWithoutExtension($safe)))" $dst | Out-Null
      }
    } catch { Write-Warning "не скачан: $($f.name) — $($_.Exception.Message)" }
  }
}
Write-Output "dump: $dump"
Write-Output "files: $(Join-Path $dir 'files')"
