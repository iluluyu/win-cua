# common.ps1 - shared helpers for win-cua scripts
# All scripts dot-source this. English-only on purpose: PowerShell 5.1 reads
# BOM-less UTF-8 as ANSI, which would garble non-ASCII literals.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class WinCuaNative {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
'@

function Get-ForegroundTitle {
    $sb = New-Object System.Text.StringBuilder 256
    [WinCuaNative]::GetWindowText([WinCuaNative]::GetForegroundWindow(), $sb, 256) | Out-Null
    $sb.ToString()
}

# Find a top-level UIA window. Params (any one):
#   -Name <string>  fuzzy match on window title (case-insensitive substring)
#   -PidNum <int>   match by process id
# Returns the AutomationElement, or $null. On ambiguous -Name matches,
# prints candidates and throws so the caller stops.
function Find-CuaWindow {
    param([string]$Name, [int]$PidNum = 0)
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $cond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Window)
    $wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)

    $candidates = New-Object System.Collections.ArrayList
    foreach ($w in $wins) {
        $title = $w.Current.Name
        if ([string]::IsNullOrWhiteSpace($title)) { continue }
        if ($Name) { if ($title -notlike "*$Name*") { continue } }
        if ($PidNum -gt 0) {
            if ($w.Current.ProcessId -ne $PidNum) { continue }
        }
        [void]$candidates.Add($w)
    }

    if ($candidates.Count -eq 0) { return $null }
    if ($candidates.Count -gt 1 -and -not $PidNum) {
        Write-Host "AMBIGUOUS: $($candidates.Count) windows match '$Name'. Be more specific or use -PidNum:"
        foreach ($c in $candidates) {
            $pn = (Get-Process -Id $c.Current.ProcessId -ErrorAction SilentlyContinue).ProcessName
            Write-Host ("  pid={0} exe={1} title=""{2}""" -f $c.Current.ProcessId, $pn, $c.Current.Name)
        }
        throw "ambiguous window match"
    }
    $candidates[0]
}

# Pretty pattern names supported by an element, e.g. "InvokePattern,ValuePattern"
# ProgrammaticName looks like "InvokePatternIdentifiers.Pattern"
function Get-PatternNames {
    param($Element)
    ($Element.GetSupportedPatterns() | ForEach-Object {
        $_.ProgrammaticName -replace 'PatternIdentifiers\.Pattern$','Pattern' -replace '^.*\.',''
    }) -join ','
}

function Format-Rect {
    param($r)
    if ($r.IsEmpty) { return '' }
    "({0},{1},{2},{3})" -f [int]$r.X, [int]$r.Y, [int]$r.Width, [int]$r.Height
}
