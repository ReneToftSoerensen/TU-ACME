function Test-IsFqdnHostname {
    <#
    .SYNOPSIS
        Returns $true when the supplied hostname looks like a fully-qualified
        domain name acceptable to an ACME CA, $false otherwise.
    .DESCRIPTION
        Used by Invoke-IISOrderFromBindings to flag IIS binding hostnames
        that aren't FQDN-shaped (single-label NetBIOS-style names like
        'ACME01P', empty/catch-all bindings, IP literals) before the
        operator places an order against them.

        TU-ACME wraps an internal corporate CA which may well accept
        single-label names, so this helper is purely advisory — callers
        warn and let the operator continue rather than rejecting.

        Rules:
          * empty / whitespace          → $false
          * no dots                     → $false (single-label, NetBIOS-style)
          * starts/ends with '.'        → $false
          * any label > 63 chars        → $false
          * total length > 253 chars    → $false
          * contains an underscore      → $false (illegal in DNS hostnames)
          * looks like an IPv4 literal  → $false
          * contains '*' anywhere other than as the leftmost label → $false
          * otherwise                   → $true
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()][AllowEmptyString()]
        [string] $Hostname
    )

    if ([string]::IsNullOrWhiteSpace($Hostname)) { return $false }
    $h = $Hostname.Trim()

    if ($h.Length -gt 253)              { return $false }
    if ($h.StartsWith('.'))             { return $false }
    if ($h.EndsWith('.'))               { return $false }
    if ($h.Contains('_'))               { return $false }
    if ($h -match '^\d+\.\d+\.\d+\.\d+$') { return $false }   # IPv4 literal

    $labels = $h -split '\.'
    if ($labels.Count -lt 2) { return $false }                # single-label

    for ($i = 0; $i -lt $labels.Count; $i++) {
        $lbl = $labels[$i]
        if ($lbl.Length -lt 1 -or $lbl.Length -gt 63) { return $false }
        if ($lbl -eq '*') {
            # Wildcards are only legal in the leftmost label.
            if ($i -ne 0) { return $false }
            continue
        }
        if ($lbl.Contains('*'))                       { return $false }
        if ($lbl -notmatch '^[A-Za-z0-9-]+$')         { return $false }
        if ($lbl.StartsWith('-') -or $lbl.EndsWith('-')) { return $false }
    }

    return $true
}
