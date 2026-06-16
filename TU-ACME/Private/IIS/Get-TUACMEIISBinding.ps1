function Get-TUACMEIISBinding {
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    if (-not (Test-TUACMEIsWindows)) {
        return @()
    }

    $provider = Get-TUACMEIISProvider
    if ($null -eq $provider) {
        Write-Verbose 'No IIS provider (WebAdministration / IISAdministration) is available; no bindings to discover.'
        return @()
    }

    # Normalise both providers to a common raw shape so the parsing and cert
    # resolution below stay provider-agnostic: each record carries SiteName,
    # Protocol, BindingInformation and CertHashRaw. No -Protocol filter, so HTTP
    # rows are listed alongside HTTPS rows (UC-9.01).
    $rawBindings = @()
    if ($provider -eq 'IISAdministration') {
        # PowerShell 7 path: WebAdministration is unreliable under Core (issue #16).
        foreach ($site in @(Get-IISSite)) {
            foreach ($binding in @($site.Bindings)) {
                $certHashRaw = $null
                # CertificateHash is only valid on SSL bindings; reading it on a
                # plain HTTP binding throws, so guard on protocol.
                if ([string]$binding.Protocol -eq 'https') {
                    try {
                        $certHashRaw = $binding.CertificateHash
                    }
                    catch {
                        $certHashRaw = $null
                    }
                }
                $rawBindings += [pscustomobject]@{
                    SiteName           = [string]$site.Name
                    Protocol           = [string]$binding.Protocol
                    BindingInformation = [string]$binding.BindingInformation
                    CertHashRaw        = $certHashRaw
                }
            }
        }
    }
    else {
        # Windows PowerShell 5.1 path: the site name lives in the ItemXPath.
        foreach ($binding in @(Get-WebBinding)) {
            $siteName = ''
            if ([string]$binding.ItemXPath -match "@name='([^']+)'") {
                $siteName = $Matches[1]
            }
            $rawBindings += [pscustomobject]@{
                SiteName           = $siteName
                Protocol           = [string]$binding.protocol
                BindingInformation = [string]$binding.bindingInformation
                CertHashRaw        = $binding.certificateHash
            }
        }
    }

    # Build thumbprint→cert lookup maps once; avoids O(bindings×certs) cost.
    $storeCertMap = @{}
    foreach ($storeName in @('WebHosting', 'My')) {
        $map = @{}
        try {
            Get-ChildItem -Path ('Cert:\LocalMachine\{0}' -f $storeName) -ErrorAction Stop |
                ForEach-Object { $map[$_.Thumbprint] = $_ }
        }
        catch { }
        $storeCertMap[$storeName] = $map
    }

    $results = @()
    foreach ($binding in $rawBindings) {
        $protocol = $binding.Protocol
        $bindingInformation = $binding.BindingInformation

        # IIS format is ip:port:hostheader; IPv6 addresses contain extra ':'
        # so a simple split on ':' misidentifies the host segment. Greedy
        # regex matches the last port:hostheader pair correctly for both
        # IPv4 (*:443:host) and IPv6 ([::1]:443:host).
        $hostHeader = ''
        if ($bindingInformation -match '^(.*):(\d{1,5}):(.*)$') {
            $hostHeader = $Matches[3]
        }

        $siteName = $binding.SiteName

        # certificateHash may be a byte[] or a string depending on the IIS/OS
        # version and provider. Normalise to uppercase hex so the value matches
        # the Thumbprint property of X509Certificate2 objects.
        $certHashRaw = $binding.CertHashRaw
        $thumbprint = ''
        if ($certHashRaw -is [byte[]] -and $certHashRaw.Count -gt 0) {
            $thumbprint = ($certHashRaw | ForEach-Object { $_.ToString('X2') }) -join ''
        }
        elseif ($null -ne $certHashRaw) {
            $thumbprint = (([string]$certHashRaw) -replace '[\s\-]', '').ToUpperInvariant()
        }
        $notAfter = $null
        $template = ''

        if ($protocol -eq 'https' -and -not [string]::IsNullOrEmpty($thumbprint)) {
            # WebHosting is the IIS-canonical store; My is the fallback.
            # An unresolvable thumbprint leaves Expires/Template blank
            # rather than throwing (UC-9.01).
            $certificate = $null
            foreach ($storeName in @('WebHosting', 'My')) {
                if ($storeCertMap[$storeName].ContainsKey($thumbprint)) {
                    $certificate = $storeCertMap[$storeName][$thumbprint]
                    break
                }
            }

            if ($null -ne $certificate) {
                $notAfter = $certificate.NotAfter
                $template = Get-TUACMECertificateTemplateName -Certificate $certificate
            }
        }

        $results += [pscustomobject]@{
            SiteName           = $siteName
            Protocol           = $protocol
            BindingInformation = $bindingInformation
            HostHeader         = $hostHeader
            Thumbprint         = $thumbprint
            NotAfter           = $notAfter
            Template           = $template
        }
    }

    return $results
}
