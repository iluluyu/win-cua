# text.ps1 - read text from a background window via UIA patterns (no focus steal).
# Tries TextPattern (full document text) then ValuePattern (field value).
# Usage: text.ps1 -Name "Notepad" [-MaxChars 4000]
param(
    [string]$Name,
    [int]$PidNum = 0,
    [int]$MaxChars = 4000
)
. "$PSScriptRoot\common.ps1"

$w = Find-CuaWindow -Name $Name -PidNum $PidNum
if (-not $w) { Write-Host "WINDOW NOT FOUND"; exit 1 }

$before = Get-ForegroundTitle
$found = $false

# TextPattern: richest source (documents, edits)
$tpCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::IsTextPatternAvailableProperty, $true)
$docs = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tpCond)
$i = 0
foreach ($d in $docs) {
    if ($i -ge 3) { break }
    $ct = $d.Current.ControlType.ProgrammaticName.Split('.')[-1]
    $tp = $d.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern)
    $txt = $tp.DocumentRange.GetText(-1)
    if ($txt.Length -gt $MaxChars) { $txt = $txt.Substring(0, $MaxChars) + " ...[truncated, total $($txt.Length) chars shown $MaxChars]" }
    Write-Host "=== TextPattern [$ct] ==="
    Write-Host $txt
    $found = $true; $i++
}

# ValuePattern fallback for fields
if (-not $found) {
    $vpCond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::IsValuePatternAvailableProperty, $true)
    $vals = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, $vpCond)
    $i = 0
    foreach ($v in $vals) {
        if ($i -ge 5) { break }
        $vp = $v.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
        Write-Host ("=== ValuePattern ""$($v.Current.Name)"" ===")
        Write-Host $vp.Current.Value
        $found = $true; $i++
    }
}
if (-not $found) { Write-Host "NO TEXT/VALUE PATTERN EXPOSED (try: tree.ps1 to inspect structure)" }

$after = Get-ForegroundTitle
Write-Host "---"
Write-Host ("focus untouched: " + ($before -eq $after))
