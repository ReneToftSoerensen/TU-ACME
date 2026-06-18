function Get-TUACMEKnownName {
    <#
    .SYNOPSIS
    Collects well-known names on the system as quick-pick CN / SAN candidates.

    .DESCRIPTION
    Aggregates the names operators most often want on a certificate so the order
    workflow can offer them as a pre-populated pick-list instead of forcing the
    operator to type each one (issue #21):

    - the machine FQDN (Source 'FQDN'),
    - the short / NetBIOS hostname (Source 'Hostname'), and
    - every host header currently bound in IIS site bindings
      (Source 'IIS host header').

    Candidates are returned in that order and de-duplicated case-insensitively so
    a host header that matches the FQDN or hostname is not offered twice. Each
    element is a [pscustomobject] with Name and Source properties. Returns an
    empty array when nothing can be resolved (for example, a non-Windows host with
    no IIS and no resolvable DNS name), in which case the order helper falls back
    to manual entry.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    # OrdinalIgnoreCase so 'Host.Domain' and 'host.domain' collapse to one entry.
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $results = New-Object System.Collections.Generic.List[object]

    $machine = $null
    try {
        $machine = Get-TUACMELocalMachineName
    }
    catch {
        $machine = $null
    }

    if ($null -ne $machine) {
        $fqdn = [string]$machine.Fqdn
        if (-not [string]::IsNullOrEmpty($fqdn) -and $seen.Add($fqdn)) {
            $results.Add([pscustomobject]@{ Name = $fqdn; Source = 'FQDN' })
        }

        $hostName = [string]$machine.HostName
        if (-not [string]::IsNullOrEmpty($hostName) -and $seen.Add($hostName)) {
            $results.Add([pscustomobject]@{ Name = $hostName; Source = 'Hostname' })
        }
    }

    # Get-TUACMEIISBinding already returns an empty list off-Windows or when no
    # IIS provider is present, so this loop is a no-op in those cases.
    foreach ($binding in @(Get-TUACMEIISBinding)) {
        $hostHeader = [string]$binding.HostHeader
        if (-not [string]::IsNullOrEmpty($hostHeader) -and $seen.Add($hostHeader)) {
            $results.Add([pscustomobject]@{ Name = $hostHeader; Source = 'IIS host header' })
        }
    }

    return $results.ToArray()
}
