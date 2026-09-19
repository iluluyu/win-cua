# tree.ps1 - dump the UIA control tree of a window in the BACKGROUND
# (no activation, no focus steal; verified: foreground window unchanged).
# Usage:
#   tree.ps1 -Name "Notepad" [-Depth 4] [-Interactive]
#   tree.ps1 -PidNum 1234 [-Depth 3]
#   -Interactive shows only actionable controls (buttons, menus, edits, ...)
param(
    [string]$Name,
    [int]$PidNum = 0,
    [int]$Depth = 4,
    [switch]$Interactive
)
. "$PSScriptRoot\common.ps1"

$w = Find-CuaWindow -Name $Name -PidNum $PidNum
if (-not $w) { Write-Host "WINDOW NOT FOUND"; exit 1 }

$pn = (Get-Process -Id $w.Current.ProcessId -ErrorAction SilentlyContinue).ProcessName
$before = Get-ForegroundTitle
Write-Host ("window: ""$($w.Current.Name)"" pid=$($w.Current.ProcessId) exe=$pn rect=$(Format-Rect $w.Current.BoundingRectangle)")

$interactiveTypes = @(
    'Button','MenuItem','TabItem','ListItem','Edit','Hyperlink','ComboBox',
    'CheckBox','RadioButton','Document','DataItem','TreeItem','Slider','Spinner','Menu'
)

$walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
$count = 0
function Dump($el, $lvl) {
    # NOTE: PS vars are case-INsensitive - never name a fn param like a script param
    if ($lvl -gt $Depth -or $count -gt 400) { return }
    $ct = $el.Current.ControlType.ProgrammaticName.Split('.')[-1]
    if ($Interactive) {
        if ($interactiveTypes -notcontains $ct) { }
        else {
            $nm = $el.Current.Name; if ($nm.Length -gt 40) { $nm = $nm.Substring(0,40) }
            $pats = Get-PatternNames $el
            Write-Host ("{0}{1,-12} ""{2}"" [{3}] {4}" -f ('  ' * $lvl), $ct, $nm, $pats, (Format-Rect $el.Current.BoundingRectangle))
            $count++
        }
    }
    else {
        $nm = $el.Current.Name; if ($nm.Length -gt 40) { $nm = $nm.Substring(0,40) }
        $aid = $el.Current.AutomationId
        Write-Host ("{0}{1,-12} ""{2}"" aid={3}" -f ('  ' * $lvl), $ct, $nm, $aid)
        $count++
    }
    $c = $walker.GetFirstChild($el)
    while ($c) { Dump $c ($lvl + 1); $c = $walker.GetNextSibling($c) }
}
Dump $w 0

$after = Get-ForegroundTitle
Write-Host "---"
Write-Host ("focus untouched: " + ($before -eq $after))
