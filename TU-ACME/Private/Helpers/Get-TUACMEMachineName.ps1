function Get-TUACMEMachineName {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    # Isolating the .NET DNS calls in this dedicated function lets the
    # aggregator (Get-TUACMESystemNameCandidate) mock this wholesale in unit
    # tests, so its candidate-list logic can be verified without depending on
    # the test host's actual DNS configuration.
    $hostname = ''
    $fqdn = ''

    try {
        $hostname = [System.Net.Dns]::GetHostName()
    }
    catch {
        $hostname = ''
    }

    try {
        $resolved = ([System.Net.Dns]::GetHostEntry($hostname)).HostName

        # A bare short name (no domain suffix) is not a usable FQDN, so treat a
        # result that merely echoes the short hostname as "no FQDN".
        if (-not [string]::IsNullOrWhiteSpace($resolved) -and
            -not ($resolved -eq $hostname)) {
            $fqdn = $resolved
        }
    }
    catch {
        $fqdn = ''
    }

    return [pscustomobject]@{
        Fqdn     = $fqdn
        Hostname = $hostname
    }
}
