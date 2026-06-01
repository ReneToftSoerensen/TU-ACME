function Invoke-IISOrderFromBindings {
    <#
    .SYNOPSIS
        Collects hostnames from IIS site bindings, warns on non-FQDN
        entries, then dispatches one or more orders via
        Invoke-OrderCertificate.
    .DESCRIPTION
        Operator workflow:

          1. Scan every binding (Get-WebBinding, no protocol filter so
             HTTP-only sites are reachable from this flow too).
          2. Group bindings by site and present a numeric multi-select
             prompt. Operator types e.g. "1,3" or "all".
          3. Collect every distinct hostname across the chosen sites,
             skipping empty/catch-all binding entries.
          4. Run Test-IsFqdnHostname on each hostname and render the
             list with `[ok]` or `[WARN]` markers. Single-label NetBIOS-
             style names produce a warning but remain in the order set
             — internal corporate CAs typically accept them, so it's an
             advisory not a block.
          5. If multiple hostnames remain, ask whether to bundle them
             into a single cert (SANs) or order one cert per hostname.
          6. Dispatch by calling Invoke-OrderCertificate with -Domain
             and -Sans so the existing plugin / plugin-args / summary /
             confirmation flow runs unchanged.
    #>
    [CmdletBinding()]
    param()

    Use-TUACMEProdAccount

    Write-Host ''
    Write-Host '  === Order new certificate from IIS bindings ===' -ForegroundColor Cyan
    Write-Host ''

    # Ask challenge type ONCE at the top of this flow. Both the
    # bundle-into-one-cert and one-cert-per-hostname dispatch paths
    # pass the chosen type into Invoke-OrderCertificate so the per-
    # order plugin picker is already filtered to the right family.
    $challengeType = ''
    while ($true) {
        $ctAns = Read-LineOrEscape -Prompt 'Challenge type [1=DNS-01, 2=HTTP-01]'
        if ($null -eq $ctAns) {
            Write-Host '  Cancelled (Esc).' -ForegroundColor Yellow
            return
        }
        switch ($ctAns.Trim().ToLowerInvariant()) {
            '1'       { $challengeType = 'dns-01';  break }
            'dns-01'  { $challengeType = 'dns-01';  break }
            '2'       { $challengeType = 'http-01'; break }
            'http-01' { $challengeType = 'http-01'; break }
            default   {
                Write-Host '  Invalid choice. Enter 1 (DNS-01) or 2 (HTTP-01).' -ForegroundColor Yellow
            }
        }
        if ($challengeType) { break }
    }

    $bindings = @(Get-WebBinding)
    if ($bindings.Count -eq 0) {
        Write-Host '  No IIS bindings found.' -ForegroundColor Yellow
        Read-Host 'Press Enter to continue' | Out-Null
        return
    }

    # Group bindings by site name (extracted from ItemXPath).
    $sitesMap = [ordered]@{}
    foreach ($b in $bindings) {
        $siteName = ''
        if ($b.ItemXPath) {
            $siteName = ($b.ItemXPath -replace ".*@name='([^']+)'.*", '$1')
        }
        if (-not $siteName) { continue }
        if (-not $sitesMap.Contains($siteName)) {
            $sitesMap[$siteName] = New-Object System.Collections.Generic.List[object]
        }
        $sitesMap[$siteName].Add($b)
    }

    $siteNames = @($sitesMap.Keys)
    if ($siteNames.Count -eq 0) {
        Write-Host '  No sites found in bindings.' -ForegroundColor Yellow
        Read-Host 'Press Enter to continue' | Out-Null
        return
    }

    Write-Host '  Sites:' -ForegroundColor Cyan
    for ($i = 0; $i -lt $siteNames.Count; $i++) {
        Write-Host ("    {0}. {1}" -f ($i + 1), $siteNames[$i])
    }
    Write-Host ''

    $pickRaw = Read-LineOrEscape -Prompt "Pick sites (comma-separated, or 'all')"
    if ($null -eq $pickRaw) {
        Write-Host '  Cancelled (Esc).' -ForegroundColor Yellow
        return
    }

    $chosenSites = @()
    $pickTrim = $pickRaw.Trim()
    if ($pickTrim -eq '' -or $pickTrim -ieq 'all') {
        $chosenSites = @($siteNames)
    } else {
        $tokens = @($pickTrim -split '[,\s]+' | Where-Object { $_ -ne '' })
        foreach ($t in $tokens) {
            $n = 0
            if (-not [int]::TryParse($t, [ref]$n) -or $n -lt 1 -or $n -gt $siteNames.Count) {
                Write-Host "  Invalid selection: '$t'." -ForegroundColor Yellow
                Read-Host 'Press Enter to continue' | Out-Null
                return
            }
            $chosenSites += $siteNames[$n - 1]
        }
        $chosenSites = @($chosenSites | Select-Object -Unique)
    }

    if ($chosenSites.Count -eq 0) {
        Write-Host '  No sites selected.' -ForegroundColor Yellow
        Read-Host 'Press Enter to continue' | Out-Null
        return
    }

    # Collect every distinct hostname across chosen sites' bindings.
    $hostnames = New-Object System.Collections.Generic.List[string]
    foreach ($s in $chosenSites) {
        foreach ($b in $sitesMap[$s]) {
            $parts = $b.bindingInformation -split ':', 3
            $hn = if ($parts.Count -ge 3) { $parts[2] } else { '' }
            if ([string]::IsNullOrWhiteSpace($hn)) { continue }
            if (-not $hostnames.Contains($hn)) { $hostnames.Add($hn) }
        }
    }

    if ($hostnames.Count -eq 0) {
        Write-Host '  Selected sites have no hostnames in their bindings (all catch-all).' -ForegroundColor Yellow
        Read-Host 'Press Enter to continue' | Out-Null
        return
    }

    Write-Host ''
    Write-Host '  Hostnames collected from selected sites:' -ForegroundColor Cyan
    $warned = $false
    foreach ($hn in $hostnames) {
        if (Test-IsFqdnHostname $hn) {
            Write-Host ("    [ok]   {0}" -f $hn) -ForegroundColor Green
        } else {
            Write-Host ("    [WARN] {0}  (not FQDN-shaped — internal CA only)" -f $hn) -ForegroundColor Yellow
            $warned = $true
        }
    }
    Write-Host ''
    if ($warned) {
        Write-Host '  One or more hostnames are not FQDN-shaped.' -ForegroundColor Yellow
        Write-Host '  Public ACME CAs reject single-label names; internal AD CS often accepts them.' -ForegroundColor Yellow
        Write-Host ''
    }

    # Bundle question only matters when there's more than one hostname.
    $bundle = $true
    if ($hostnames.Count -gt 1) {
        $bundleAns = Read-LineOrEscape -Prompt 'Bundle all hostnames into ONE certificate (SANs)? (Y/n)'
        if ($null -eq $bundleAns) {
            Write-Host '  Cancelled (Esc).' -ForegroundColor Yellow
            return
        }
        if ($bundleAns -match '^[nN]') { $bundle = $false }
    }

    if ($bundle) {
        $primary = $hostnames[0]
        $sans    = @()
        if ($hostnames.Count -gt 1) {
            $sans = @($hostnames | Select-Object -Skip 1)
        }
        Invoke-OrderCertificate -Domain $primary -Sans $sans -ChallengeType $challengeType
    } else {
        for ($i = 0; $i -lt $hostnames.Count; $i++) {
            $hn = $hostnames[$i]
            Write-Host ''
            Write-Host ("  --- Order {0} of {1}: {2} ---" -f ($i + 1), $hostnames.Count, $hn) -ForegroundColor Cyan
            Invoke-OrderCertificate -Domain $hn -Sans @() -ChallengeType $challengeType
        }
    }
}
