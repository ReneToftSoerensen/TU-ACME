function Get-TUACMEOrderDomain {
    <#
    .SYNOPSIS
    Prompts the operator for the certificate domains to order (CN + optional SANs).

    .DESCRIPTION
    Collects the FQDN that becomes the certificate CN / primary domain, then
    collects any number of Subject Alternative Names. When well-known names are
    available on the system (machine FQDN, short hostname, and IIS bound host
    headers, via Get-TUACMEKnownName) the operator is offered a pre-populated
    quick-pick list so they can select names instead of typing them (issue #21):

    - The CN is chosen from the pick-list, or via 'Enter a name manually...'.
    - SANs are added one at a time from the remaining candidates (or typed
      manually), finishing with 'Done' or Esc. Each pick that is already selected
      is hidden so the same name is never offered twice.

    When no known names can be resolved the helper falls back to the typed
    convention: it reads the FQDN, then offers a short-hostname SAN defaulted to
    the first DNS label of the FQDN (Enter accepts the default, '-' skips the SAN,
    any other value overrides it).

    Returns an array suitable for Invoke-TUACMEOrderCertificate -Domain: the first
    element is the CN and any further elements are SANs, de-duplicated
    case-insensitively. Returns an empty array when the operator cancels or leaves
    the FQDN blank (the menu treats this as "do nothing").

    Single-label short hostnames (no dot) are only issuable by an internal CA;
    public CAs reject them. TU-ACME targets an internal CA per SPEC.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )

    # Case-insensitive membership test used to de-dupe selected names so the same
    # host is never requested twice (mirrors the public/internal CA behaviour).
    function Test-NameSelected {
        param([string]$Name, [string[]]$Selected)

        foreach ($entry in $Selected) {
            if ([string]::Equals($entry, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
        return $false
    }

    $known = @(Get-TUACMEKnownName)
    $manualLabel = 'Enter a name manually...'

    # --- Common Name (primary domain) ---
    $cn = ''
    if ($known.Count -gt 0) {
        $cnItems = @($known | ForEach-Object { '{0}  [{1}]' -f $_.Name, $_.Source })
        $cnItems += $manualLabel

        $cnTitle = [string]$Prompt
        if ($cnTitle.Length -gt 79) {
            $cnTitle = $cnTitle.Substring(0, 79)
        }

        $cnSelection = Show-TUACMEMenu -Title $cnTitle -Items $cnItems
        # Esc (-1) cancels the whole order: the menu treats this as "do nothing".
        if ($cnSelection -lt 0) {
            return @()
        }
        if ($cnSelection -lt $known.Count) {
            $cn = [string]$known[$cnSelection].Name
        }
        else {
            $cn = ([string](Read-Host $Prompt)).Trim()
        }
    }
    else {
        $cn = ([string](Read-Host $Prompt)).Trim()
    }

    if ([string]::IsNullOrEmpty($cn)) {
        return @()
    }

    $selected = @($cn)

    # --- Subject Alternative Names (optional, zero or more) ---
    if ($known.Count -gt 0) {
        $doneLabel = 'Done - no more SANs'

        while ($true) {
            # Hide names already chosen (including the CN) so each candidate is
            # only ever offered once.
            $available = @($known | Where-Object {
                    -not (Test-NameSelected -Name $_.Name -Selected $selected)
                })

            $sanItems = @($available | ForEach-Object { '{0}  [{1}]' -f $_.Name, $_.Source })
            $sanItems += $manualLabel
            $sanItems += $doneLabel

            $sanTitle = 'Add SAN to {0} (selected SANs: {1})' -f $cn, ($selected.Count - 1)
            if ($sanTitle.Length -gt 79) {
                $sanTitle = $sanTitle.Substring(0, 79)
            }

            $sanSelection = Show-TUACMEMenu -Title $sanTitle -Items $sanItems
            # Esc finishes SAN selection with whatever has been chosen so far.
            if ($sanSelection -lt 0 -or $sanSelection -eq ($sanItems.Count - 1)) {
                break
            }
            if ($sanSelection -eq ($sanItems.Count - 2)) {
                $manual = ([string](Read-Host 'SAN to add')).Trim()
                if (-not [string]::IsNullOrEmpty($manual) -and -not (Test-NameSelected -Name $manual -Selected $selected)) {
                    $selected += $manual
                }
                continue
            }

            $selected += [string]$available[$sanSelection].Name
        }
    }
    else {
        # No known names to pick from: keep the typed default short-hostname SAN
        # convention. Default the SAN to the first DNS label (text before the
        # first dot); for a single-label FQDN the default equals the FQDN and the
        # de-dupe below keeps the order to a single name.
        $defaultShort = $cn
        $firstDot = $cn.IndexOf('.')
        if ($firstDot -gt 0) {
            $defaultShort = $cn.Substring(0, $firstDot)
        }

        $shortAnswer = ([string](Read-Host ('Short hostname SAN (Enter for "{0}", "-" to skip)' -f $defaultShort))).Trim()

        # Enter (empty answer) accepts the default; '-' is the explicit skip
        # sentinel; anything else overrides the default. Read-Host cannot tell
        # Enter from a blank line, so the dash sentinel gives operators a
        # deterministic way to opt out of the SAN.
        if ($shortAnswer -ne '-') {
            $shortName = $defaultShort
            if (-not [string]::IsNullOrEmpty($shortAnswer)) {
                $shortName = $shortAnswer
            }
            if (-not [string]::IsNullOrEmpty($shortName) -and -not (Test-NameSelected -Name $shortName -Selected $selected)) {
                $selected += $shortName
            }
        }
    }

    return @($selected)
}
