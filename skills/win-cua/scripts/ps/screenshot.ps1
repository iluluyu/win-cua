# screenshot.ps1 - capture without stealing focus.
#   -Window <name> : PrintWindow API - works on BACKGROUND windows (Chromium ok with flag 2)
#   -All           : full virtual screen via GDI CopyFromScreen (no input side effects)
#   -Region "x,y,w,h" : crop of virtual screen
# Usage: screenshot.ps1 -Window "Notepad" [-Out "C:\Users\me\shot.png"]
# Prints "SAVED: <windows-path>" on success. run.sh converts it to a WSL path.
param(
    [string]$Window,
    [switch]$All,
    [string]$Region,
    [string]$Out
)
. "$PSScriptRoot\common.ps1"

if (-not $Out) {
    $dir = Join-Path $env:USERPROFILE 'win-cua-shots'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $Out = Join-Path $dir ("shot-{0}.png" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
if ($Out -notmatch '^[A-Za-z]:') { Write-Host "ERROR: -Out must be a Windows path like C:\Users\...\x.png"; exit 1 }

$before = Get-ForegroundTitle

if ($Window) {
    $w = Find-CuaWindow -Name $Window
    if (-not $w) { Write-Host "WINDOW NOT FOUND"; exit 1 }
    $h = [IntPtr]$w.Current.NativeWindowHandle
    if ($h -eq [IntPtr]::Zero) { Write-Host "ERROR: no native window handle"; exit 1 }
    $r = $w.Current.BoundingRectangle
    $bw = [int]$r.Width; $bh = [int]$r.Height
    if ($bw -le 0 -or $bh -le 0) { Write-Host "ERROR: window has zero size (minimized?)"; exit 1 }
    $bmp = New-Object System.Drawing.Bitmap($bw, $bh)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    # flag 2 = PW_RENDERFULLCONTENT (needed for Chromium/DirectUI content)
    [void][WinCuaNative]::PrintWindow($h, $hdc, 2)
    $g.ReleaseHdc($hdc); $g.Dispose()
    $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
elseif ($Region) {
    $parts = $Region.Split(','); if ($parts.Count -ne 4) { Write-Host "ERROR: -Region expects x,y,w,h"; exit 1 }
    $x=[int]$parts[0]; $y=[int]$parts[1]; $bw=[int]$parts[2]; $bh=[int]$parts[3]
    $bmp = New-Object System.Drawing.Bitmap($bw, $bh)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size($bw, $bh)))
    $g.Dispose(); $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
else {
    $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bmp = New-Object System.Drawing.Bitmap($vs.Width, $vs.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($vs.X, $vs.Y, 0, 0, $bmp.Size)
    $g.Dispose(); $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}

$after = Get-ForegroundTitle
Write-Host ("SAVED: $Out")
Write-Host ("focus untouched: " + ($before -eq $after))
