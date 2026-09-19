# tree.ps1 - dump a window's UIA control tree in the BACKGROUND (no focus steal).
#   tree.ps1 -Name "Notepad" [-Interactive] [-Depth 4] [-PidNum <pid>]
#   -Interactive: show only actionable controls (buttons, menus, edits, ...).
#                 Non-matching parents are skipped but still recursed into.
param(
    [string]$Name,
    [int]$PidNum = 0,
    [int]$Depth = 4,
    [switch]$Interactive
)
. "$PSScriptRoot\common.ps1"

$w = Find-CuaWindow -Name $Name -PidNum $PidNum
if (-not $w) { Write-Host "WINDOW NOT FOUND"; exit 1 }

$before = Get-ForegroundTitle
$pn = (Get-Process -Id $w.Current.ProcessId -ErrorAction SilentlyContinue).ProcessName
Write-Host ("window: ""$($w.Current.Name)"" pid=$($w.Current.ProcessId) exe=$pn rect=$(Format-Rect $w.Current.BoundingRectangle)")

$actionable = @('Button','MenuItem','TabItem','ListItem','Edit','Hyperlink','ComboBox',
                'CheckBox','RadioButton','Document','DataItem','TreeItem','Slider','Spinner','Menu')
$walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker

function Dump($el, $lvl) {
    # PS variables are case-insensitive: fn args must not shadow script params ($Depth)
    if ($lvl -gt $Depth) { return }
    $ct = $el.Current.ControlType.ProgrammaticName.Split('.')[-1]
    if (-not $Interactive -or $actionable -contains $ct) {
        $nm = $el.Current.Name; if ($nm.Length -gt 40) { $nm = $nm.Substring(0,40) }
        Write-Host ("{0}{1,-12} ""{2}"" [{3}] {4}" -f ('  ' * $lvl), $ct, $nm,
            (Get-PatternNames $el), (Format-Rect $el.Current.BoundingRectangle))
    }
    $c = $walker.GetFirstChild($el)
    while ($c) { Dump $c ($lvl + 1); $c = $walker.GetNextSibling($c) }
}
Dump $w 0

$after = Get-ForegroundTitle
Write-Host "---"
Write-Host ("focus untouched: " + ($before -eq $after))
