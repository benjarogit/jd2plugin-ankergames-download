# Find JDownloader install folders (normal + portable) on Windows.
# Double-click or: powershell -ExecutionPolicy Bypass -File find-jd-home.ps1
$ErrorActionPreference = "Stop"

function Test-JdHome([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }
    return (Test-Path -LiteralPath (Join-Path $Path "JDownloader.jar")) -and
           (Test-Path -LiteralPath (Join-Path $Path "Core.jar")) -and
           (Test-Path -LiteralPath (Join-Path $Path "jd\plugins") -PathType Container)
}

$found = New-Object System.Collections.Generic.List[string]

function Add-Jd([string]$Path) {
    if (-not $Path) { return }
    try {
        $full = (Resolve-Path -LiteralPath $Path).Path
    } catch { return }
    if (-not (Test-JdHome $full)) { return }
    if (-not $found.Contains($full)) { $found.Add($full) }
}

Write-Host "Searching for JDownloader…" -ForegroundColor Cyan

# Well-known
$candidates = @(
    (Join-Path $env:USERPROFILE ".jd"),
    (Join-Path $env:USERPROFILE "jd2"),
    (Join-Path $env:USERPROFILE "JDownloader2"),
    (Join-Path $env:USERPROFILE "JDownloader 2.0"),
    (Join-Path $env:USERPROFILE "Desktop\JDownloader 2.0"),
    (Join-Path $env:USERPROFILE "Downloads\JDownloader 2.0"),
    "C:\Program Files\JDownloader",
    "C:\Program Files (x86)\JDownloader",
    "C:\JDownloader",
    "D:\JDownloader",
    "E:\JDownloader"
)
foreach ($c in $candidates) { Add-Jd $c }

# Shortcut targets (Start Menu / Desktop)
$shortcutRoots = @(
    [Environment]::GetFolderPath("Desktop"),
    [Environment]::GetFolderPath("StartMenu"),
    (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs")
)
foreach ($root in $shortcutRoots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem -LiteralPath $root -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "jdownloader" } |
        ForEach-Object {
            try {
                $sh = New-Object -ComObject WScript.Shell
                $target = $sh.CreateShortcut($_.FullName).TargetPath
                if ($target) { Add-Jd (Split-Path -Parent $target) }
            } catch {}
        }
}

# File search under user profile (portable)
Write-Host "Scanning user profile for JDownloader.jar (may take a minute)…" -ForegroundColor DarkGray
Get-ChildItem -Path $env:USERPROFILE -Filter "JDownloader.jar" -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 40 |
    ForEach-Object { Add-Jd $_.DirectoryName }

Write-Host ""
if ($found.Count -eq 0) {
    Write-Host "No JDownloader folder found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "What to try next:"
    Write-Host "  1) Start JDownloader once (so it creates its folder)"
    Write-Host "  2) Right-click the shortcut -> Open file location"
    Write-Host "  3) Win+S search for:  JDownloader.jar"
    Write-Host "     -> that folder is your JD root (Core.jar + jd\ next to it)"
    Write-Host "  4) Portable: look where you extracted JD"
    Write-Host "     (Desktop, Downloads, USB, another drive)"
    Write-Host "  5) Or search for  Core.jar  (must sit next to JDownloader.jar)"
    Write-Host ""
    Write-Host "Copy plugins into:  <JD-Root>\jd\plugins\"
    Write-Host "More detail: README.md / README.de.md -> If nothing is found"
    pause
    exit 1
}

Write-Host "Found JDownloader install(s):" -ForegroundColor Green
Write-Host ""
$i = 1
foreach ($d in $found) {
    Write-Host "----------------------------------------"
    Write-Host "  #$i"
    Write-Host "  JD root:"
    Write-Host "    $d"
    Write-Host "  Plugin folder (copy here):"
    Write-Host "    $(Join-Path $d 'jd\plugins\')"
    Write-Host "  Patch Core.jar:"
    Write-Host "    $(Join-Path $d 'Core.jar')"
    Write-Host ""
    $i++
}

if ($found.Count -gt 1) {
    Write-Host "Multiple installs — use the one you actually start (check your shortcut)." -ForegroundColor Yellow
}

Write-Host "Press Enter to close…"
[void][System.Console]::ReadLine()
