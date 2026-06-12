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

    $results = @()
    foreach ($binding in $bindings) {
        $protocol = [string]$binding.protocol
        $bindingInformation = [string]$binding.bindingInformation

        $hostHeader = ''
        $parts = $bindingInformation -split ':'
        if ($parts.Count -ge 3) {
            $hostHeader = $parts[2]
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
                $storeCerts = @()
                try {
                    $storeCerts = @(Get-ChildItem -Path ('Cert:\LocalMachine\{0}' -f $storeName) -ErrorAction Stop)
                }
                catch {
                    $storeCerts = @()
                }
                $certificate = @($storeCerts | Where-Object { $_.Thumbprint -eq $thumbprint })[0]
                if ($null -ne $certificate) {
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
