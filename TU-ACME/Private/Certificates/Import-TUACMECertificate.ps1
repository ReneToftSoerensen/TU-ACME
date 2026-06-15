function Import-TUACMECertificate {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # Posh-ACME certificate object (PfxFullChain, PfxPass, MainDomain).
        [Parameter(Mandatory = $true)]
        [object]$Certificate,

        # One or more LocalMachine stores to import into. Renewal/order use the
        # default (My); the IIS rebind path also imports into WebHosting so IIS
        # can read the cert from its canonical store (UC-9.02).
        [ValidateSet('My', 'WebHosting')]
        [string[]]$StoreName = @('My')
    )

    if (-not (Test-TUACMEIsWindows)) {
        throw 'Certificate import requires Windows.'
    }

    $pfxPath = [string]$Certificate.PfxFullChain
    if ([string]::IsNullOrEmpty($pfxPath) -or -not (Test-Path -LiteralPath $pfxPath)) {
        throw ('Certificate PFX not found at ''{0}''.' -f $pfxPath)
    }

    $thumbprint = ''
    foreach ($store in $StoreName) {
        $importParams = @{
            FilePath          = $pfxPath
            CertStoreLocation = ('Cert:\LocalMachine\{0}' -f $store)
            Exportable        = $true
            ErrorAction       = 'Stop'
        }
        if ($null -ne $Certificate.PSObject.Properties['PfxPass'] -and $null -ne $Certificate.PfxPass) {
            $importParams['Password'] = $Certificate.PfxPass
        }

        # A full-chain PFX can import multiple certs; the leaf is the one with
        # the private key, and its thumbprint is what bindings reference.
        $imported = @(Import-PfxCertificate @importParams)
        if ($imported.Count -eq 0) {
            throw 'Import-PfxCertificate returned no certificates; the PFX may be corrupt or access was denied.'
        }
        $leaf = @($imported | Where-Object { $_.HasPrivateKey })
        if ($leaf.Count -eq 0) {
            $leaf = $imported
        }
        $thumbprint = [string]$leaf[0].Thumbprint

        Write-TUACMEEventLog -EventId 1011 -EntryType Information -Message ('Certificate for {0} imported to LocalMachine\{1} (thumbprint {2}).' -f $Certificate.MainDomain, $store, $thumbprint)
    }

    return $thumbprint
}
