function Get-TUACMESystemNameCandidate {
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    $candidates = @()

    # Machine names come first so an FQDN/Hostname keeps its descriptive label
    # even when an IIS binding later repeats the same name.
    $machine = Get-TUACMEMachineName
    if (-not [string]::IsNullOrWhiteSpace($machine.Fqdn)) {
        $candidates += [pscustomobject]@{ Name = [string]$machine.Fqdn; Source = 'FQDN' }
    }
    if (-not [string]::IsNullOrWhiteSpace($machine.Hostname)) {
        $candidates += [pscustomobject]@{ Name = [string]$machine.Hostname; Source = 'Hostname' }
    }

    foreach ($binding in @(Get-TUACMEIISBinding)) {
        $hostHeader = [string]$binding.HostHeader
        if (-not [string]::IsNullOrWhiteSpace($hostHeader)) {
            $candidates += [pscustomobject]@{ Name = $hostHeader; Source = 'IIS' }
        }
    }

    # De-duplicate case-insensitively by Name, keeping the first occurrence so
    # the machine-name labels win over any repeated IIS host header.
    $results = @()
    $seen = @{}
    foreach ($candidate in $candidates) {
        $key = $candidate.Name.ToLowerInvariant()
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $results += $candidate
        }
    }

    return $results
}
