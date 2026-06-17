function Invoke-TUACMEOrderCertificate {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The first element is the CN / primary domain; any additional
        # elements become Subject Alternative Names. New-PACertificate already
        # treats the first -Domain entry as MainDomain and the rest as SANs.
        [Parameter(Mandatory = $true)]
        [string[]]$Domain,

        [switch]$DryRun
    )

    $config = Get-TUACMEConfig
    $dns = Get-TUACMEDNSConfig

    # -Domain is [string[]]; a caller can still pass blank entries or an array
    # that trims down to nothing. Normalise and require at least one usable
    # name so the primary domain (and the 3002 message) is never empty.
    $Domain = @($Domain | ForEach-Object { ([string]$_).Trim() } | Where-Object { -not [string]::IsNullOrEmpty($_) })
    if ($Domain.Count -eq 0) {
        throw 'At least one non-empty domain is required to order a certificate.'
    }

    # The order body takes its inputs as parameters (no closure) so it stays
    # bound to the module session state on both the prod and dry-run paths.
    $orderOperation = {
        param($OrderDomain, $ContactEmail, $DnsConfig)

        # The CN / primary domain is the first entry; pass the full array to
        # New-PACertificate so the remaining entries are issued as SANs, but
        # surface the primary as a scalar for the return value and messages.
        $primaryDomain = $OrderDomain[0]

        $orderParams = @{
            Domain      = $OrderDomain
            Contact     = $ContactEmail
            AcceptTOS   = $true
            ErrorAction = 'Stop'
        }
        if ($null -ne $DnsConfig) {
            $orderParams['Plugin'] = $DnsConfig.PluginName
            $orderParams['PluginArgs'] = $DnsConfig.PluginArgs
        }

        $certificate = New-PACertificate @orderParams
        if ($null -eq $certificate) {
            throw ('New-PACertificate returned no certificate for {0}.' -f $primaryDomain)
        }

        return [pscustomobject]@{
            Domain     = $primaryDomain
            Thumbprint = [string]$certificate.Thumbprint
            NotAfter   = $certificate.NotAfter
        }
    }

    if ($DryRun) {
        # Staging swap, prod restore, and event 1006 are owned by
        # Invoke-TUACMEDryRun (UC-3.01); dry-run certs are never imported.
        # Build the argument list explicitly so the $Domain array is preserved
        # as a single positional argument (a bare @(...) list would flatten the
        # SAN entries into separate arguments).
        $dryRunArgs = New-Object 'System.Collections.ArrayList'
        $null = $dryRunArgs.Add($Domain)
        $null = $dryRunArgs.Add($config.ContactEmail)
        $null = $dryRunArgs.Add($dns)
        return (Invoke-TUACMEDryRun -Operation $orderOperation -ArgumentList $dryRunArgs.ToArray())
    }

    # The CN / primary domain (first entry) drives the 3002 failure message so
    # it stays a scalar even though $Domain may now carry SANs.
    $primaryDomain = $Domain[0]

    $null = Use-TUACMEProdAccount
    try {
        $result = & $orderOperation $Domain $config.ContactEmail $dns
    }
    catch {
        Write-TUACMEEventLog -EventId 3002 -EntryType Error -Message ('Certificate order for {0} failed: {1}' -f $primaryDomain, $_.Exception.Message)
        throw
    }

    Write-TUACMEEventLog -EventId 1003 -EntryType Information -Message ('Certificate ordered for {0} (thumbprint {1}).' -f $result.Domain, $result.Thumbprint)
    return $result
}
