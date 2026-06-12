function Show-TUACMEMenu {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, 79)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string[]]$Items,

        [int[]]$DisabledIndices = @()
    )

    function Test-ItemMatch {
        param([string]$Item, [string]$Filter)

        if ([string]::IsNullOrEmpty($Filter)) {
            return $true
        }
        # Plain case-insensitive substring match: -like would treat the
        # operator-typed *, ?, and [ as wildcard metacharacters, and an
        # unbalanced [ would throw out of the menu loop (UC-4.02).
        return ($Item.IndexOf($Filter, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
    }

    function Get-SelectableIndices {
        param([string]$Filter)

        $indices = @()
        for ($i = 0; $i -lt $Items.Count; $i++) {
            if ($DisabledIndices -contains $i) {
                continue
            }
            if (-not (Test-ItemMatch -Item $Items[$i] -Filter $Filter)) {
                continue
            }
            $indices += $i
        }
        return $indices
    }

    function Move-Selection {
        param([int]$Current, [int]$Direction, [int[]]$Selectable)

        if ($Selectable.Count -eq 0) {
            return -1
        }
        $position = [array]::IndexOf($Selectable, $Current)
        if ($position -lt 0) {
            return $Selectable[0]
        }
        $position = ($position + $Direction) % $Selectable.Count
        if ($position -lt 0) {
            $position += $Selectable.Count
        }
        return $Selectable[$position]
    }

    if (@(Get-SelectableIndices -Filter '').Count -eq 0) {
        throw 'Show-TUACMEMenu requires at least one enabled item.'
    }

    # $null search text means not searching; '' means search mode with an
    # empty buffer (every item matches).
    $searchText = $null
    $selectable = @(Get-SelectableIndices -Filter '')
    $selected = $selectable[0]

    while ($true) {
        Clear-Host
        Write-Host $Title -ForegroundColor DarkCyan
        if ($null -ne $searchText) {
            Write-Host ('Search: {0}' -f $searchText) -ForegroundColor DarkCyan
        }

        for ($i = 0; $i -lt $Items.Count; $i++) {
            $isVisible = ($null -eq $searchText) -or (Test-ItemMatch -Item $Items[$i] -Filter $searchText)
            if (-not $isVisible) {
                continue
            }

            if ($DisabledIndices -contains $i) {
                Write-Host ('  {0}' -f $Items[$i]) -ForegroundColor DarkCyan
            }
            elseif ($i -eq $selected) {
                Write-Host ('> {0}' -f $Items[$i]) -ForegroundColor Cyan -BackgroundColor DarkCyan
            }
            else {
                Write-Host ('  {0}' -f $Items[$i]) -ForegroundColor Cyan
            }
        }
        Write-Host 'Arrows move, Enter selects, / searches, Esc cancels.' -ForegroundColor DarkCyan

        $key = Read-TUACMEKey
        $keyName = [string]$key.Key

        if ($keyName -eq 'UpArrow') {
            $selected = Move-Selection -Current $selected -Direction -1 -Selectable $selectable
            continue
        }
        if ($keyName -eq 'DownArrow') {
            $selected = Move-Selection -Current $selected -Direction 1 -Selectable $selectable
            continue
        }
        if ($keyName -eq 'Enter') {
            if ($selected -ge 0 -and $selectable -contains $selected) {
                return $selected
            }
            continue
        }

        if ($null -ne $searchText) {
            if ($keyName -eq 'Escape') {
                $searchText = $null
                $selectable = @(Get-SelectableIndices -Filter '')
                $selected = $selectable[0]
                continue
            }
            if ($keyName -eq 'Backspace') {
                if ($searchText.Length -gt 0) {
                    $searchText = $searchText.Substring(0, $searchText.Length - 1)
                }
            }
            elseif ($key.KeyChar -ne [char]0 -and -not [char]::IsControl($key.KeyChar)) {
                $searchText = $searchText + $key.KeyChar
            }
            else {
                continue
            }

            $selectable = @(Get-SelectableIndices -Filter $searchText)
            $selected = -1
            if ($selectable.Count -gt 0) {
                $selected = $selectable[0]
            }
            continue
        }

        if ($keyName -eq 'Escape') {
            return -1
        }
        if ($key.KeyChar -eq '/') {
            $searchText = ''
            continue
        }
    }
}
