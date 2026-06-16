function New-TUACMEIISHttpsBinding {
    <#
    .SYNOPSIS
    Orders a certificate for an IIS site and provisions its HTTPS binding (UC-9.04).

    .DESCRIPTION
    The previously-deferred order-from-bindings flow (UC-9.01 / UC-9.02 future
    scope): orders a certificate for the chosen CN (+ SANs), imports it into the
    IIS-canonical WebHosting store, then creates (or updates) the site's HTTPS
    binding at the requested port/host header and attaches the new cert. A
    dry-run orders against staging and makes NO import and NO IIS changes
    (UC-3.01). The binding is provisioned through the session's IIS provider
    (WebAdministration on Windows PowerShell 5.1, IISAdministration on
    PowerShell 7), selected via Get-TUACMEIISProvider (issue #16). Never touches
    IIS on a non-Windows host or when no IIS provider is available.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteName,

        # CN / primary domain; becomes the first -Domain entry of the order.
        [Parameter(Mandatory = $true)]
        [string]$Domain,

        # Additional Subject Alternative Names appended after the CN.
        [string[]]$San = @(),

        [ValidateRange(1, 65535)]
        [int]$Port = 443,

        # HTTPS binding host header; commonly equals the CN. Empty means an
        # all-hosts binding (no SNI).
        [string]$HostHeader = '',

        [switch]$DryRun
    )

    # The CN is the first entry; SANs follow. De-dupe so a SAN that repeats the
    # CN never orders the same name twice (mirrors Get-TUACMEOrderDomain).
    $domains = @($Domain)
    foreach ($name in $San) {
        $trimmed = ([string]$name).Trim()
        if (-not [string]::IsNullOrEmpty($trimmed) -and ($domains -notcontains $trimmed)) {
            $domains += $trimmed
        }
    }

    if ($DryRun) {
        # Order routes through staging in Invoke-TUACMEOrderCertificate; no
        # import and no IIS changes happen on this path (UC-3.01).
        $order = Invoke-TUACMEOrderCertificate -Domain $domains -DryRun
        return [pscustomobject]@{
            Domain         = $order.Domain
            Thumbprint     = $order.Thumbprint
            Port           = $Port
            HostHeader     = $HostHeader
            SiteName       = $SiteName
            DryRun         = $true
            BindingCreated = $false
            BindingUpdated = $false
        }
    }

    # Order first so a binding is only provisioned once a real cert exists; the
    # order fn logs 1003 / 3002 itself.
    $order = Invoke-TUACMEOrderCertificate -Domain $domains

    # Select the IIS provider that works in this session: WebAdministration on
    # Windows PowerShell 5.1, IISAdministration on PowerShell 7 (issue #16).
    # Guard before importing so an unavailable provider never imports needlessly.
    $provider = Get-TUACMEIISProvider
    if (-not (Test-TUACMEIsWindows) -or $null -eq $provider) {
        # DarkCyan is the advisory/remediation tone (AC-C.4); the cert was still
        # ordered, but this path created no binding and needs operator action.
        Write-Host 'IIS management is unavailable; install IIS Management Scripts and Tools, or run under Windows PowerShell 5.1. Certificate ordered but no HTTPS binding was created.' -ForegroundColor DarkCyan
        return [pscustomobject]@{
            Domain         = $order.Domain
            Thumbprint     = $order.Thumbprint
            Port           = $Port
            HostHeader     = $HostHeader
            SiteName       = $SiteName
            DryRun         = $false
            BindingCreated = $false
            BindingUpdated = $false
        }
    }

    # Get-PACertificate returns the importable object (PfxFullChain/PfxPass);
    # the order fn deliberately does not import (mirrors the renewal path).
    $paCert = Get-PACertificate -MainDomain $Domain

    # Import into both stores so the binding resolves the thumbprint regardless
    # of store name; WebHosting is the IIS-canonical store (UC-9.02). Returns
    # the leaf thumbprint that the binding references.
    $thumbprint = Import-TUACMECertificate -Certificate $paCert -StoreName @('My', 'WebHosting')

    # IIS binding information is ip:port:hostheader; an all-hosts binding has an
    # empty host segment. Match Get-TUACMEIISBinding so an existing binding is
    # found and updated instead of duplicated.
    $bindingInformation = '*:{0}:{1}' -f $Port, $HostHeader

    # SNI is only meaningful with a host header; an all-hosts binding cannot use
    # it. The certificateHash/Name attach path is identical either way.
    $sslFlags = 0
    if (-not [string]::IsNullOrEmpty($HostHeader)) {
        $sslFlags = 1
    }

    $bindingCreated = $false
    $bindingUpdated = $false
    try {
        $existing = @(Get-TUACMEIISBinding | Where-Object {
                $_.SiteName -eq $SiteName -and
                $_.Protocol -eq 'https' -and
                $_.BindingInformation -eq $bindingInformation
            })

        if ($provider -eq 'IISAdministration') {
            # PowerShell 7 path: there is no New-WebBinding/Set-WebBinding, so the
            # binding is created via the Microsoft.Web.Administration ServerManager
            # and the cert is attached through Set-TUACMEIISBindingCertificate,
            # which commits its own changes (issue #16).
            if ($existing.Count -eq 0) {
                $manager = Get-IISServerManager
                $site = $manager.Sites[$SiteName]
                if ($null -eq $site) {
                    throw ("IIS site '{0}' was not found." -f $SiteName)
                }
                $newBinding = $site.Bindings.Add($bindingInformation, 'https')
                # SetAttributeValue sets the SNI flag; an all-hosts binding leaves
                # sslFlags at its default 0 so the attribute is only touched when
                # a host header is present.
                if ($sslFlags -ne 0) {
                    $newBinding.SetAttributeValue('sslFlags', $sslFlags)
                }
                $manager.CommitChanges()
                $bindingCreated = $true
            }
            else {
                $bindingUpdated = $true
            }

            Set-TUACMEIISBindingCertificate -SiteName $SiteName -BindingInformation $bindingInformation -Thumbprint $thumbprint -StoreName 'WebHosting'
        }
        else {
            if ($existing.Count -eq 0) {
                $newBindingParams = @{
                    Name        = $SiteName
                    Protocol    = 'https'
                    Port        = $Port
                    IPAddress   = '*'
                    SslFlags    = $sslFlags
                    ErrorAction = 'Stop'
                }
                if (-not [string]::IsNullOrEmpty($HostHeader)) {
                    $newBindingParams['HostHeader'] = $HostHeader
                }
                New-WebBinding @newBindingParams
                $bindingCreated = $true
            }
            else {
                $bindingUpdated = $true
            }

            # Update the hash before switching the store name: the cert lives in
            # both stores, so the binding serves it immediately under any store name
            # and a failed store switch never strands the binding (UC-9.02).
            Set-WebBinding -Name $SiteName -BindingInformation $bindingInformation -PropertyName 'certificateHash' -Value $thumbprint -ErrorAction Stop
            Set-WebBinding -Name $SiteName -BindingInformation $bindingInformation -PropertyName 'certificateStoreName' -Value 'WebHosting' -ErrorAction Stop
        }

        Write-TUACMEEventLog -EventId 1002 -EntryType Information -Message ('HTTPS binding {0} on site ''{1}'' provisioned with thumbprint {2}.' -f $bindingInformation, $SiteName, $thumbprint)
    }
    catch {
        Write-TUACMEEventLog -EventId 2001 -EntryType Warning -Message ('HTTPS binding {0} on site ''{1}'' failed: {2}' -f $bindingInformation, $SiteName, $_.Exception.Message)
        throw
    }

    return [pscustomobject]@{
        Domain         = $order.Domain
        Thumbprint     = $thumbprint
        Port           = $Port
        HostHeader     = $HostHeader
        SiteName       = $SiteName
        DryRun         = $false
        BindingCreated = $bindingCreated
        BindingUpdated = $bindingUpdated
    }
}
