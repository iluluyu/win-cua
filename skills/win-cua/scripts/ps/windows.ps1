# windows.ps1 - list top-level windows (perception, zero focus impact)
param()
. "$PSScriptRoot\common.ps1"

$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window)
$wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
$fg = Get-ForegroundTitle

Write-Host ("foreground: ""$fg""")
Write-Host ("top-level windows: " + $wins.Count)
foreach ($w in $wins) {
    $title = $w.Current.Name
    if ([string]::IsNullOrWhiteSpace($title)) { continue }
    $pid2 = $w.Current.ProcessId
    $pn = (Get-Process -Id $pid2 -ErrorAction SilentlyContinue).ProcessName
    $rect = Format-Rect $w.Current.BoundingRectangle
    $off = $w.Current.IsOffscreen
    Write-Host ("  pid={0,-6} exe={1,-18} offscreen={2,-5} rect={3,-26} ""{4}""" -f $pid2, $pn, $off, $rect, $title)
}
