function Get-TUACMEIISBinding {
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    if (-not (Test-TUACMEIsWindows)) {
        return @()
    }

    if ($null -eq (Get-Command -Name 'Get-WebBinding' -ErrorAction SilentlyContinue)) {
        Write-Verbose 'WebAdministration is not available; no IIS bindings to discover.'
        return @()
    }

    # No -Protocol filter: HTTP rows are listed alongside HTTPS (UC-9.01).
    $bindings = @(Get-WebBinding)

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
    foreach ($binding in $bindings) {
        $protocol = [string]$binding.protocol
        $bindingInformation = [string]$binding.bindingInformation

        # IIS format is ip:port:hostheader; IPv6 addresses contain extra ':'
        # so a simple split on ':' misidentifies the host segment. Greedy
        # regex matches the last port:hostheader pair correctly for both
        # IPv4 (*:443:host) and IPv6 ([::1]:443:host).
        $hostHeader = ''
        if ($bindingInformation -match '^(.*):(\d{1,5}):(.*)$') {
            $hostHeader = $Matches[3]
        }

        $siteName = ''
        if ([string]$binding.ItemXPath -match "@name='([^']+)'") {
            $siteName = $Matches[1]
        }

        $thumbprint = [string]$binding.certificateHash
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
