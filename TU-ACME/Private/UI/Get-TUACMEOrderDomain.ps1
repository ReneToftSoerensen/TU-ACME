function Get-TUACMEOrderDomain {
    <#
    .SYNOPSIS
    Prompts the operator for the certificate domains to order (CN + optional SAN).

    .DESCRIPTION
    Collects the FQDN that becomes the certificate CN / primary domain, then
    offers a short-hostname Subject Alternative Name defaulted to the first DNS
    label of the FQDN. Convention for the SAN prompt: pressing Enter accepts the
    proposed default, typing '-' skips the SAN entirely, and any other value
    overrides the default. Returns an array suitable for
    Invoke-TUACMEOrderCertificate -Domain: the first element is the CN and any
    second element is the short-hostname SAN. Returns an empty array when the
    operator leaves the FQDN blank (the menu treats this as "do nothing").

    Single-label short hostnames (no dot) are only issuable by an internal CA;
    public CAs reject them. TU-ACME targets an internal CA per SPEC.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )

    $fqdn = ([string](Read-Host $Prompt)).Trim()
    if ([string]::IsNullOrEmpty($fqdn)) {
        return @()
    }

    # Default the SAN to the first DNS label (text before the first dot). For a
    # single-label FQDN the default equals the FQDN; the de-dupe below keeps the
    # order to a single name in that case.
    $defaultShort = $fqdn
    $firstDot = $fqdn.IndexOf('.')
    if ($firstDot -gt 0) {
        $defaultShort = $fqdn.Substring(0, $firstDot)
    }

    $shortAnswer = ([string](Read-Host ('Short hostname SAN (Enter for "{0}", "-" to skip)' -f $defaultShort))).Trim()

    # Enter (empty answer) accepts the default; '-' is the explicit skip
    # sentinel; anything else overrides the default. Read-Host cannot tell Enter
    # from a blank line, so the dash sentinel gives operators a deterministic way
    # to opt out of the SAN.
    if ($shortAnswer -eq '-') {
        return @($fqdn)
    }

    $shortName = $defaultShort
    if (-not [string]::IsNullOrEmpty($shortAnswer)) {
        $shortName = $shortAnswer
    }

    # De-dupe: a single-label FQDN (or an override equal to the FQDN) collapses
    # to a single-name order rather than ordering the same name twice.
    if ([string]::IsNullOrEmpty($shortName) -or ($shortName -eq $fqdn)) {
        return @($fqdn)
    }

    return @($fqdn, $shortName)
}
