# act.ps1 - act on a control in a background window via UIA patterns.
# LAYER 1 automation: goes through the accessibility COM channel, does NOT
# require the window to be focused/foreground (verified: focus untouched).
#
# Usage:
#   act.ps1 -Name "Notepad" -Target "File" -Action menu        # invoke menu item / button
#   act.ps1 -Name "Settings" -Target "Dark mode" -Action toggle # toggle check box
#   act.ps1 -Name "Tree" -Target "Advanced" -Action expand     # expand tree node
#   act.ps1 -Name "List" -Target "Item A" -Action select       # select list item / tab
#   act.ps1 -Name "Notepad" -Target "Text Editor" -Action setvalue -Value "hello"
#   act.ps1 -Name "Dialog" -Action close                       # WindowPattern.Close
#
# Target matching: substring, case-insensitive, within the whole window tree.
# If several controls match, candidates are printed - refine or use -ControlType.
param(
    [string]$Name,
    [int]$PidNum = 0,
    [string]$Target,
    [string]$Action = "invoke",       # invoke|toggle|expand|collapse|select|setvalue|close
    [string]$Value,
    [string]$ControlType              # optional filter: Button, MenuItem, TabItem, ...
)
. "$PSScriptRoot\common.ps1"

$w = Find-CuaWindow -Name $Name -PidNum $PidNum
if (-not $w) { Write-Host "WINDOW NOT FOUND"; exit 1 }
if ($Action -ne 'close' -and -not $Target) { Write-Host "ERROR: -Target required for action '$Action'"; exit 1 }

$before = Get-ForegroundTitle
$scope = [System.Windows.Automation.TreeScope]::Descendants

# Build search condition
$cond = $null
if ($ControlType) {
    $ct = [System.Windows.Automation.ControlType]::LookupByName($ControlType)
    if (-not $ct) { Write-Host "ERROR: unknown ControlType '$ControlType'"; exit 1 }
    $cond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ct)
} else {
    $cond = [System.Windows.Automation.Condition]::TrueCondition
}

$all = $w.FindAll($scope, $cond)
$hits = New-Object System.Collections.ArrayList
if ($Action -ne 'close') {
    foreach ($e in $all) {
        if ($e.Current.Name -like "*$Target*") { [void]$hits.Add($e) }
    }
    if ($hits.Count -eq 0) { Write-Host "TARGET NOT FOUND: ""$Target"" (run tree.ps1 to see control names)"; exit 1 }
    if ($hits.Count -gt 1) {
        Write-Host "AMBIGUOUS TARGET: $($hits.Count) matches for ""$Target"":"
        foreach ($h in $hits) {
            Write-Host ("  {0} ""{1}"" [{2}]" -f $h.Current.ControlType.ProgrammaticName.Split('.')[-1], $h.Current.Name, (Get-PatternNames $h))
        }
        exit 1
    }

    $el = $hits[0]
    $ctName = $el.Current.ControlType.ProgrammaticName.Split('.')[-1]
    Write-Host ("target: $ctName ""$($el.Current.Name)"" patterns=[$(Get-PatternNames $el)]")
}

switch ($Action) {
    'invoke' {
        $p = $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
        if (-not $p) { Write-Host "NO InvokePattern on target"; exit 1 }
        $p.Invoke(); Write-Host "OK invoke"
    }
    'toggle' {
        $p = $el.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
        if (-not $p) { Write-Host "NO TogglePattern on target"; exit 1 }
        $p.Toggle(); Write-Host "OK toggle (state now: $($p.Current.ToggleState))"
    }
    'expand' {
        $p = $el.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern)
        if (-not $p) { Write-Host "NO ExpandCollapsePattern"; exit 1 }
        $p.Expand(); Write-Host "OK expand"
    }
    'collapse' {
        $p = $el.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern)
        if (-not $p) { Write-Host "NO ExpandCollapsePattern"; exit 1 }
        $p.Collapse(); Write-Host "OK collapse"
    }
    'select' {
        $p = $el.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
        if (-not $p) { Write-Host "NO SelectionItemPattern"; exit 1 }
        $p.Select(); Write-Host "OK select"
    }
    'setvalue' {
        if (-not $Value) { Write-Host "ERROR: -Value required"; exit 1 }
        $p = $el.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
        if (-not $p) { Write-Host "NO ValuePattern"; exit 1 }
        $p.SetValue($Value); Write-Host "OK setvalue"
    }
    'close' {
        $p = $w.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
        if (-not $p) { Write-Host "NO WindowPattern on window"; exit 1 }
        $p.Close(); Write-Host "OK close (window asked to close; unsaved-changes dialogs may appear)"
    }
    default { Write-Host "ERROR: unknown action '$Action'"; exit 1 }
}

Start-Sleep -Milliseconds 250
$after = Get-ForegroundTitle
Write-Host "---"
Write-Host ("focus untouched: " + ($before -eq $after))
Write-Host "VERIFY: re-run tree.ps1 / text.ps1 to confirm the UI changed as intended."
