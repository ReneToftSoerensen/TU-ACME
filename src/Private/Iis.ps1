<#
    Iis.ps1 - Reading and editing IIS bindings via IISAdministration
    (Microsoft.Web.Administration through Get-IISServerManager).
#>

function ConvertTo-ThumbprintBytes {
    <#
        .SYNOPSIS
            Converts a hex thumbprint string to the byte[] IIS stores in
            CertificateHash. Centralised; never inline this conversion.
    #>
    param([Parameter(Mandatory)][string]$Thumbprint)
    $bytes = [byte[]]::new($Thumbprint.Length / 2)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = [Convert]::ToByte($Thumbprint.Substring($i * 2, 2), 16)
    }
    return , $bytes
}

function Get-IISServerManagerSafe {
    <#
        .SYNOPSIS
            Wraps Get-IISServerManager with a clear message when the
            Microsoft.Web.Administration types fail to load (PS7/host issue).
    #>
    try {
        return Get-IISServerManager
    } catch {
        throw "Could not load IIS management types (Microsoft.Web.Administration). Ensure the IISAdministration module and IIS are installed. Underlying error: $_"
    }
}

function Get-IISBindingsRaw {
    <#
        .SYNOPSIS
            Flattens every IIS binding into normalised rows (IP/Port/HostHeader,
            current cert hash + store).
    #>
    $mgr = Get-IISServerManagerSafe
    foreach ($site in $mgr.Sites) {
        foreach ($b in $site.Bindings) {
            $parts   = $b.BindingInformation -split ':', 3
            $ip      = if ($parts[0]) { $parts[0] } else { '*' }
            $port    = if ($parts[1]) { $parts[1] } else { '80' }
            $hostHdr = if ($parts.Count -ge 3 -and $parts[2]) { $parts[2] } else { '' }
            $certHash = if ($b.CertificateHash) {
                ([BitConverter]::ToString($b.CertificateHash)).Replace('-', '').ToLower()
            } else { '' }

            [pscustomobject]@{
                SiteName         = $site.Name
                SiteID           = $site.Id
                Protocol         = $b.Protocol
                IPAddress        = $ip
                Port             = $port
                HostHeader       = $hostHdr
                BindingInformation = $b.BindingInformation
                CertificateHash  = $certHash
                CertificateStore = $b.CertificateStore
                SslFlags         = [string]$b.SslFlags
            }
        }
    }
}

function ConvertTo-WacsFilter {
    param([string]$Raw)
    if (-not $Raw) { return @() }
    $Raw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
}

function Test-WacsHostPattern {
    <#
        .SYNOPSIS
            WACS-style wildcard match ('*' and '?') against a host header.
    #>
    param([string]$Value, [string[]]$Patterns)
    foreach ($p in $Patterns) {
        $escaped = [regex]::Escape($p)
        $pattern = $escaped -replace '\\\*', '.*'
        $pattern = $pattern -replace '\\\?', '.'
        if ($Value -match ('^' + $pattern + '$')) { return $true }
    }
    return $false
}

function Get-IISFilteredSites {
    param([string]$SiteFilter)
    $mgr = Get-IISServerManagerSafe
    $all = foreach ($s in $mgr.Sites) {
        [pscustomobject]@{ Id = $s.Id; Name = $s.Name; State = [string]$s.State; _RawObject = $s }
    }
    if (-not $SiteFilter) { return $all }
    $filter = ConvertTo-WacsFilter $SiteFilter
    if ($filter -contains 's') { return $all }
    $ids = $filter | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    if ($ids) { return @($all | Where-Object { $_.Id -in $ids }) }
    return @()
}

function Get-IISSslBindings {
    <#
        .SYNOPSIS
            Returns all HTTPS bindings with the bound cert's thumbprint, subject
            and expiry (looked up in the binding's certificate store).
    #>
    $all = Get-IISBindingsRaw | Where-Object { $_.Protocol -ieq 'https' }
    foreach ($b in $all) {
        $subject  = ''
        $notAfter = $null
        if ($b.CertificateHash) {
            try {
                $store = [Security.Cryptography.X509Certificates.X509Store]::new(
                    $b.CertificateStore, 'LocalMachine')
                $store.Open('ReadOnly')
                $cert = $store.Certificates |
                    Where-Object { $_.Thumbprint -ieq $b.CertificateHash } |
                    Select-Object -First 1
                if ($cert) { $subject = $cert.Subject; $notAfter = $cert.NotAfter }
                $store.Close()
            } catch {
                Write-Info "Could not open cert store '$($b.CertificateStore)' for $($b.CertificateHash): $_"
            }
        }
        [pscustomobject]@{
            SiteName           = $b.SiteName
            HostHeader         = $b.HostHeader
            IPAddress          = $b.IPAddress
            Port               = $b.Port
            BindingInformation = $b.BindingInformation
            BindingInfo        = "$($b.IPAddress):$($b.Port):$($b.HostHeader)"
            Thumbprint         = $b.CertificateHash
            CertStore          = $b.CertificateStore
            Subject            = $subject
            NotAfter           = $notAfter
        }
    }
}

function Get-IISBindingsByThumbprint {
    param([string]$Thumbprint)
    if (-not $Thumbprint) { return @() }
    $tp = $Thumbprint.ToLower()
    return @(Get-IISSslBindings | Where-Object { $_.Thumbprint -and $_.Thumbprint.ToLower() -eq $tp })
}

function Test-IISSiteHasHttpsRedirect {
    <#
        .SYNOPSIS
            Best-effort detection of an HTTP->HTTPS redirect (httpRedirect or a
            URL Rewrite rule) on a site, which would 301 the ACME HTTP-01
            challenge and break WebSelfHost validation.
    #>
    param([Parameter(Mandatory)][string]$SiteName)
    if (-not (Test-TUACMEOnWindows)) { return $false }
    try {
        $redirect = Get-WebConfigurationProperty -PSPath "IIS:\Sites\$SiteName" `
            -Filter 'system.webServer/httpRedirect' -Name 'enabled' -ErrorAction SilentlyContinue
        if ($redirect -and $redirect.Value) { return $true }
    } catch { }
    try {
        $rules = Get-WebConfiguration -PSPath "IIS:\Sites\$SiteName" `
            -Filter 'system.webServer/rewrite/rules/rule' -ErrorAction SilentlyContinue
        foreach ($r in @($rules)) {
            $action = $r.action
            if ($action -and $action.type -ieq 'Redirect' -and $action.url -match 'https') { return $true }
        }
    } catch { }
    return $false
}

function Set-IISBindingCertificate {
    <#
        .SYNOPSIS
            Re-points an existing HTTPS binding to a different certificate.
            Idempotent: skips when the binding already carries the target thumbprint.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$SiteName,
        [Parameter(Mandatory)][string]$BindingInformation,
        [Parameter(Mandatory)][string]$Thumbprint,
        [string]$StoreName = 'WebHosting'
    )
    if (-not $PSCmdlet.ShouldProcess("$SiteName / $BindingInformation", "rebind -> $Thumbprint")) { return }

    $mgr  = Get-IISServerManagerSafe
    $site = $mgr.Sites[$SiteName]
    if (-not $site) { throw "Site '$SiteName' not found." }
    $binding = $site.Bindings |
        Where-Object { $_.BindingInformation -eq $BindingInformation -and $_.Protocol -ieq 'https' } |
        Select-Object -First 1
    if (-not $binding) { throw "HTTPS binding '$BindingInformation' not found on '$SiteName'." }

    $current = if ($binding.CertificateHash) {
        ([BitConverter]::ToString($binding.CertificateHash)).Replace('-', '').ToLower()
    } else { '' }
    if ($current -eq $Thumbprint.ToLower() -and $binding.CertificateStore -eq $StoreName) {
        Write-Info "$SiteName / $BindingInformation already on $Thumbprint; skipping."
        return
    }

    $binding.CertificateHash  = ConvertTo-ThumbprintBytes $Thumbprint
    $binding.CertificateStore = $StoreName
    $mgr.CommitChanges()
}

function New-IISHttpsBinding {
    <#
        .SYNOPSIS
            Creates a new HTTPS binding on a site (SNI on when a host header is
            present). Idempotent: skips when an https binding with the same
            BindingInformation already exists.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$SiteName,
        [Parameter(Mandatory)][string]$HostHeader,
        [Parameter(Mandatory)][string]$Thumbprint,
        [string]$IPAddress = '*',
        [string]$Port = '443',
        [string]$StoreName = 'WebHosting'
    )
    $ip = if ($IPAddress -eq '*') { '' } else { $IPAddress }
    $bindingInfo = "{0}:{1}:{2}" -f $ip, $Port, $HostHeader
    if (-not $PSCmdlet.ShouldProcess("$SiteName / $bindingInfo", "create https binding -> $Thumbprint")) { return }

    $mgr  = Get-IISServerManagerSafe
    $site = $mgr.Sites[$SiteName]
    if (-not $site) { throw "Site '$SiteName' not found." }

    $existing = $site.Bindings |
        Where-Object { $_.BindingInformation -eq $bindingInfo -and $_.Protocol -ieq 'https' } |
        Select-Object -First 1
    if ($existing) {
        Write-Info "HTTPS binding '$bindingInfo' already exists on '$SiteName'; skipping create."
        return
    }

    $new = $site.Bindings.CreateElement('binding')
    $new.Protocol           = 'https'
    $new.BindingInformation = $bindingInfo
    $new.CertificateStore   = $StoreName
    $new.CertificateHash    = ConvertTo-ThumbprintBytes $Thumbprint
    if ($HostHeader) { try { $new.SslFlags = 1 } catch { } }  # SNI when host header present
    $site.Bindings.Add($new)
    $mgr.CommitChanges()
}
