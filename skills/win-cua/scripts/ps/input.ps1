# input.ps1 - LAYER 3 LAST RESORT: physical input via SendInput.
# This MOVES THE REAL MOUSE / TYPES ON THE REAL KEYBOARD - it will steal the
# user's focus and cursor. It must never be used silently.
#
# SAFETY: requires the explicit -ConfirmPhysical flag. Without it, the script
# only prints what it WOULD do (dry run).
#
# Usage:
#   input.ps1 -MouseClick -X 100 -Y 200 [-Button right] [-Double] -ConfirmPhysical
#   input.ps1 -MouseMove -X 100 -Y 200 -ConfirmPhysical
#   input.ps1 -TypeText "hello world" -ConfirmPhysical
#   input.ps1 -Keys "^s" -ConfirmPhysical
#   -TypeText/-Keys use SendKeys syntax: + ^ % ~ ( ) { } [ ] are special chars.
param(
    [switch]$MouseClick, [switch]$MouseMove, [switch]$TypeText, [switch]$Keys,
    [int]$X = -1, [int]$Y = -1,
    [ValidateSet('left','right','middle')][string]$Button = 'left',
    [switch]$Double,
    [string]$Text, [string]$KeySeq,
    [switch]$ConfirmPhysical
)
. "$PSScriptRoot\common.ps1"

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class WinCuaInput {
    [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public MOUSEINPUT mi; }
    [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr extra; }
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002, MOUSEEVENTF_LEFTUP = 0x0004,
        MOUSEEVENTF_RIGHTDOWN = 0x0008, MOUSEEVENTF_RIGHTUP = 0x0010, MOUSEEVENTF_MIDDLEDOWN = 0x0020,
        MOUSEEVENTF_MIDDLEUP = 0x0040;
    [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
}
'@

function Send-Mouse($downFlag, $upFlag) {
    $down = New-Object WinCuaInput+INPUT
    $down.type = 0; $down.mi.dwFlags = $downFlag
    $up = New-Object WinCuaInput+INPUT
    $up.type = 0; $up.mi.dwFlags = $upFlag
    [void][WinCuaInput]::SendInput(2, @($down, $up), [System.Runtime.InteropServices.Marshal]::SizeOf([type][WinCuaInput+INPUT]))
}

if (-not $ConfirmPhysical) {
    Write-Host "DRY RUN (no input injected). Re-run with -ConfirmPhysical to execute for real."
    if ($MouseClick) { Write-Host "would click $Button$(if($Double){' (double) '})at ($X,$Y)" }
    if ($MouseMove)  { Write-Host "would move cursor to ($X,$Y)" }
    if ($TypeText)   { Write-Host "would type: $Text" }
    if ($Keys)       { Write-Host "would press keys: $KeySeq" }
    exit 0
}

Write-Host "WARNING: injecting physical input in 1 second..."
Start-Sleep -Seconds 1

if ($MouseMove -or $MouseClick) {
    if ($X -lt 0 -or $Y -lt 0) { Write-Host "ERROR: -X/-Y required"; exit 1 }
    [void][WinCuaInput]::SetCursorPos($X, $Y)
    if ($MouseClick) {
        switch ($Button) {
            'left'   { Send-Mouse 0x0002 0x0004 }
            'right'  { Send-Mouse 0x0008 0x0010 }
            'middle' { Send-Mouse 0x0020 0x0040 }
        }
        if ($Double) { Start-Sleep -Milliseconds 80; switch ($Button) {
            'left'   { Send-Mouse 0x0002 0x0004 }
            'right'  { Send-Mouse 0x0008 0x0010 }
            'middle' { Send-Mouse 0x0020 0x0040 } } }
        Write-Host "OK clicked $Button at ($X,$Y)"
    } else { Write-Host "OK cursor moved to ($X,$Y)" }
}
elseif ($TypeText) {
    [System.Windows.Forms.SendKeys]::SendWait($Text)
    Write-Host "OK typed text (SendKeys)"
}
elseif ($Keys) {
    [System.Windows.Forms.SendKeys]::SendWait($KeySeq)
    Write-Host "OK sent keys: $KeySeq"
}
