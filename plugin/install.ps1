# AnkerGames plugin + Core Turnstile patch for JDownloader 2 (Windows)
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$PluginHoster = Join-Path $ScriptDir "plugins\hoster\AnkergamesNet.class"
$PluginCrawler = Join-Path $ScriptDir "plugins\decrypter\AnkergamesNetCrawler.class"
$PluginRelay = Join-Path $ScriptDir "plugins\components\AnkergamesCdnRelay.class"
$CoreHtml = Join-Path $RootDir "core-patch\turnstile.html"
$CoreClass = Join-Path $RootDir "core-patch\CloudflareTurnstileChallenge.class"

function Die([string]$Message) {
    Write-Error $Message
    exit 1
}

if (-not (Test-Path -LiteralPath $PluginHoster)) { Die "Missing package file: $PluginHoster" }
if (-not (Test-Path -LiteralPath $PluginCrawler)) { Die "Missing package file: $PluginCrawler" }
if (-not (Test-Path -LiteralPath $PluginRelay)) { Die "Missing package file: $PluginRelay" }
if (-not (Test-Path -LiteralPath $CoreHtml)) { Die "Missing package file: $CoreHtml" }
if (-not (Test-Path -LiteralPath $CoreClass)) { Die "Missing package file: $CoreClass" }

function Test-JdHome([string]$Path) {
    return (Test-Path -LiteralPath (Join-Path $Path "JDownloader.jar")) -and `
           (Test-Path -LiteralPath (Join-Path $Path "Core.jar")) -and `
           (Test-Path -LiteralPath (Join-Path $Path "jd\plugins"))
}

function Get-JdHome {
    if ($env:JD_HOME -and (Test-JdHome $env:JD_HOME)) {
        return $env:JD_HOME
    }
    if ($env:JD_HOME) {
        Die "JD_HOME is set but invalid: $($env:JD_HOME)"
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "JDownloader 2.0"),
        (Join-Path $env:APPDATA "JDownloader 2.0"),
        (Join-Path $env:USERPROFILE "JDownloader 2.0"),
        (Join-Path $env:USERPROFILE ".jd"),
        (Join-Path $env:USERPROFILE "jd2")
    )

    foreach ($c in $candidates) {
        if ($c -and (Test-JdHome $c)) {
            return $c
        }
    }
    Die "JDownloader folder not found. Set JD_HOME to your JD directory (contains JDownloader.jar + Core.jar)."
}

function Get-JdPids([string]$JdHome) {
    $pids = @()
    $pidFile = Join-Path $JdHome "JDownloader.pid"
    if (Test-Path -LiteralPath $pidFile) {
        $raw = (Get-Content -LiteralPath $pidFile -Raw).Trim()
        if ($raw -match '^\d+$') {
            $pids += [int]$raw
        }
    }
    Get-CimInstance Win32_Process -Filter "Name = 'java.exe' OR Name = 'javaw.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and ($_.CommandLine -match 'JDownloader\.jar') } |
        ForEach-Object { $pids += [int]$_.ProcessId }
    Get-Process -Name "JDownloader2","JDownloader" -ErrorAction SilentlyContinue |
        ForEach-Object { $pids += [int]$_.Id }
    return ($pids | Select-Object -Unique)
}

function Stop-Jd([string]$JdHome) {
    Write-Host "Stopping JDownloader ..."
    $pids = Get-JdPids $JdHome
    foreach ($procId in $pids) {
        try {
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        } catch {}
    }
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        $left = Get-JdPids $JdHome
        if (-not $left -or $left.Count -eq 0) { break }
        Start-Sleep -Seconds 1
    }
    Write-Host "JDownloader stopped."
}

function Install-Files([string]$JdHome) {
    $hosterDir = Join-Path $JdHome "jd\plugins\hoster"
    $crawlerDir = Join-Path $JdHome "jd\plugins\decrypter"
    $componentsDir = Join-Path $JdHome "jd\plugins\components"
    New-Item -ItemType Directory -Force -Path $hosterDir | Out-Null
    New-Item -ItemType Directory -Force -Path $crawlerDir | Out-Null
    New-Item -ItemType Directory -Force -Path $componentsDir | Out-Null
    Copy-Item -Path (Join-Path $ScriptDir "plugins\hoster\AnkergamesNet*.class") -Destination $hosterDir -Force
    Copy-Item -Path (Join-Path $ScriptDir "plugins\decrypter\AnkergamesNetCrawler*.class") -Destination $crawlerDir -Force
    Copy-Item -Path (Join-Path $ScriptDir "plugins\components\AnkergamesCdnRelay*.class") -Destination $componentsDir -Force

    $tmp = Join-Path $JdHome "tmp"
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    Set-Content -LiteralPath (Join-Path $tmp "hosterCache") -Value "" -NoNewline
    Set-Content -LiteralPath (Join-Path $tmp "crawlerCache") -Value "" -NoNewline
    Write-Host "Plugin classes installed (hoster + crawler + AnkergamesCdnRelay)."
}

function Patch-CoreJar([string]$JdHome) {
    $core = Join-Path $JdHome "Core.jar"
    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    $bak = "$core.bak-ankergames-$stamp"
    Copy-Item -LiteralPath $core -Destination $bak -Force
    Write-Host "Backed up Core.jar → $bak"

    $work = Join-Path $env:TEMP ("jd-core-patch-" + [guid]::NewGuid().ToString("N"))
    $dest = Join-Path $work "org\jdownloader\captcha\v2\challenge\cloudflareturnstile"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item -LiteralPath $CoreHtml -Destination (Join-Path $dest "turnstile.html") -Force
    Copy-Item -LiteralPath $CoreClass -Destination (Join-Path $dest "CloudflareTurnstileChallenge.class") -Force

    Push-Location $work
    try {
        & jar uf $core `
            "org/jdownloader/captcha/v2/challenge/cloudflareturnstile/turnstile.html" `
            "org/jdownloader/captcha/v2/challenge/cloudflareturnstile/CloudflareTurnstileChallenge.class"
        if ($LASTEXITCODE -ne 0) { Die "jar uf Core.jar failed (is JDK 'jar' on PATH?)" }
    } finally {
        Pop-Location
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Core.jar patched (Turnstile HTML + challenge class with relay metas)."
}

function Start-Jd([string]$JdHome) {
    Write-Host "Starting JDownloader ..."
    $exe = Join-Path $JdHome "JDownloader2.exe"
    if (Test-Path -LiteralPath $exe) {
        Start-Process -FilePath $exe -WorkingDirectory $JdHome
    } else {
        Start-Process -FilePath "javaw" -ArgumentList @("-jar", "JDownloader.jar") -WorkingDirectory $JdHome
    }
    Write-Host "JDownloader start requested."
}

Write-Host "=== AnkerGames JDownloader Plugin Installer ==="
$jdHome = Get-JdHome
Write-Host "JD home: $jdHome"
Stop-Jd $jdHome
Install-Files $jdHome
Patch-CoreJar $jdHome
Start-Jd $jdHome
Write-Host ""
Write-Host "Done. Next:"
Write-Host "  1) Load browser companion (see ..\README.md) — Firefox or Chromium/Vivaldi"
Write-Host "  2) Add game URL in Linkgrabber"
Write-Host "  3) Solve Turnstile; keep the AnkerGames tab open while JD downloads"
