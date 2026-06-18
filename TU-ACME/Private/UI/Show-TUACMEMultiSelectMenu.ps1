function Show-TUACMEMultiSelectMenu {
    [CmdletBinding()]
    [OutputType([int[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, 79)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string[]]$Items,

        [int[]]$DisabledIndices = @(),

        [int[]]$PreSelectedIndices = @()
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
        throw 'Show-TUACMEMultiSelectMenu requires at least one enabled item.'
    }

    # Seed the selection from PreSelectedIndices, dropping any disabled index so
    # a disabled item can never end up checked.
    $selectedSet = @{}
    foreach ($index in $PreSelectedIndices) {
        if (($DisabledIndices -notcontains $index) -and ($index -ge 0) -and ($index -lt $Items.Count)) {
            $selectedSet[$index] = $true
        }
    }

    # $null search text means not searching; '' means search mode with an
    # empty buffer (every item matches).
    $searchText = $null
    $selectable = @(Get-SelectableIndices -Filter '')
    $current = $selectable[0]

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

            $box = '[ ]'
            if ($selectedSet.ContainsKey($i)) {
                $box = '[x]'
            }

            if ($DisabledIndices -contains $i) {
                Write-Host ('  {0} {1}' -f $box, $Items[$i]) -ForegroundColor DarkCyan
            }
            elseif ($i -eq $current) {
                Write-Host ('> {0} {1}' -f $box, $Items[$i]) -ForegroundColor Cyan -BackgroundColor DarkCyan
            }
            else {
                Write-Host ('  {0} {1}' -f $box, $Items[$i]) -ForegroundColor Cyan
            }
        }
        Write-Host 'Arrows move, Space toggles, Enter confirms, / filters, Esc cancels.' -ForegroundColor DarkCyan

        $key = Read-TUACMEKey
        $keyName = [string]$key.Key

        if ($keyName -eq 'UpArrow') {
            $current = Move-Selection -Current $current -Direction -1 -Selectable $selectable
            continue
        }
        if ($keyName -eq 'DownArrow') {
            $current = Move-Selection -Current $current -Direction 1 -Selectable $selectable
            continue
        }
        if ($keyName -eq 'Enter') {
            return @([int[]]@($selectedSet.Keys) | Sort-Object)
        }

        if ($null -ne $searchText) {
            if ($keyName -eq 'Escape') {
                $searchText = $null
                $selectable = @(Get-SelectableIndices -Filter '')
                $current = $selectable[0]
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
            $current = -1
            if ($selectable.Count -gt 0) {
                $current = $selectable[0]
            }
            continue
        }

        if ($keyName -eq 'Spacebar') {
            if (($current -ge 0) -and ($selectable -contains $current)) {
                if ($selectedSet.ContainsKey($current)) {
                    $selectedSet.Remove($current)
                }
                else {
                    $selectedSet[$current] = $true
                }
            }
            continue
        }
        if ($keyName -eq 'Escape') {
            return $null
        }
        if ($key.KeyChar -eq '/') {
            $searchText = ''
            continue
        }
        if (($key.KeyChar -eq 'a') -or ($key.KeyChar -eq 'A')) {
            foreach ($index in $selectable) {
                $selectedSet[$index] = $true
            }
            continue
        }
    }
}
