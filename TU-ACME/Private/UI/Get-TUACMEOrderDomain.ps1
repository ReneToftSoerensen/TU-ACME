function Get-TUACMEOrderDomain {
    <#
    .SYNOPSIS
    Prompts the operator for the certificate domains to order (CN + optional SAN).

    .DESCRIPTION
    First offers a quick-pick step: when system name candidates are available
    (machine FQDN, short hostname, IIS bound host headers via
    Get-TUACMESystemNameCandidate) the operator multi-selects names from a
    filterable menu instead of typing. A single pick becomes the CN; picking two
    or more prompts for which name is the CN, with the rest returned as SANs.
    Cancelling (Esc), confirming an empty selection, or having no candidates
    falls back to the manual entry flow below.

    Manual fallback: collects the FQDN that becomes the certificate CN / primary
    domain, then offers a short-hostname Subject Alternative Name defaulted to
    the first DNS label of the FQDN. Convention for the SAN prompt: pressing
    Enter accepts the proposed default, typing '-' skips the SAN entirely, and
    any other value overrides the default. Returns an array suitable for
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

    # Quick-pick: let the operator select known names rather than type them.
    # Esc, an empty confirmation, or no candidates fall through to manual entry.
    $candidates = @(Get-TUACMESystemNameCandidate)
    if ($candidates.Count -gt 0) {
        $labels = @($candidates | ForEach-Object { '{0}  [{1}]' -f $_.Name, $_.Source })

        # Pre-select the FQDN row so the common single-Enter case picks it.
        $preSelected = @()
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            if ($candidates[$i].Source -eq 'FQDN') {
                $preSelected = @($i)
                break
            }
        }

        $picked = Show-TUACMEMultiSelectMenu -Title 'Pick names for the certificate (Space toggles, / filters)' -Items $labels -PreSelectedIndices $preSelected
        if (($null -ne $picked) -and (@($picked).Count -gt 0)) {
            $names = @($picked | ForEach-Object { $candidates[$_].Name })
            if ($names.Count -eq 1) {
                return @($names[0])
            }

            $cnIndex = Show-TUACMEMenu -Title 'Select the Common Name (CN); the rest become SANs' -Items $names
            if ($cnIndex -lt 0) {
                return @()
            }
            $cn = $names[$cnIndex]
            $sans = @($names | Where-Object { $_ -ne $cn })
            return @($cn) + $sans
        }
    }

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
