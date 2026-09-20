# geom.ps1 - window geometry helpers, all focus-preserving where noted.
#   geom.ps1 -ListMonitors
#   geom.ps1 -Move -Name "Notepad" -X 2000 -Y 100 [-W 800] [-H 600]   (SWP_NOACTIVATE)
#   geom.ps1 -Minimize -Name "Notepad"   (background, does not activate)
#   geom.ps1 -Restore -Name "Notepad"    (NOTE: restore ACTIVATES the window)
param(
    [switch]$ListMonitors,
    [switch]$Move, [string]$Name, [int]$PidNum = 0, [int]$X = -1, [int]$Y = -1, [int]$W = -1, [int]$H = -1,
    [switch]$Minimize, [switch]$Restore
)
. "$PSScriptRoot\common.ps1"

if ($ListMonitors) {
    foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
        $b = $s.Bounds
        $prim = if ($s.Primary) { 'primary' } else { '' }
        Write-Host ("monitor {0,-12} {1}x{2} at ({3},{4}) {5}" -f $s.DeviceName, $b.Width, $b.Height, $b.X, $b.Y, $prim)
    }
    exit 0
}

$w = Find-CuaWindow -Name $Name -PidNum $PidNum
if (-not $w) { Write-Host "WINDOW NOT FOUND"; exit 1 }
$h = [IntPtr]$w.Current.NativeWindowHandle
$before = Get-ForegroundTitle

if ($Move) {
    $r = $w.Current.BoundingRectangle
    $curW = [int]$r.Width; $curH = [int]$r.Height; $curX = [int]$r.X; $curY = [int]$r.Y
    $nx = if ($X -ge 0) { $X } else { $curX }
    $ny = if ($Y -ge 0) { $Y } else { $curY }
    $nw = if ($W -gt 0) { $W } else { $curW }
    $nh = if ($H -gt 0) { $H } else { $curH }
    # SWP_NOACTIVATE=0x0010 | SWP_NOZORDER=0x0004
    [void][WinCuaNative]::SetWindowPos($h, [IntPtr]::Zero, $nx, $ny, $nw, $nh, 0x0014)
    Write-Host "OK moved to ($nx,$ny) ${nw}x${nh} (no activation)"
}
elseif ($Minimize) {
    [void][WinCuaNative]::ShowWindow($h, 6)   # SW_MINIMIZE
    Write-Host "OK minimized (no activation)"
}
elseif ($Restore) {
    [void][WinCuaNative]::ShowWindow($h, 9)   # SW_RESTORE - this ACTIVATES the window
    Write-Host "OK restored (window is now foreground - focus was moved)"
}

$after = Get-ForegroundTitle
Write-Host ("focus untouched: " + ($before -eq $after))
