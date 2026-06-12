function Import-TUACMECertificate {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # Posh-ACME certificate object (PfxFullChain, PfxPass, MainDomain).
        [Parameter(Mandatory = $true)]
        [object]$Certificate
    )

    if (-not (Test-TUACMEIsWindows)) {
        throw 'Certificate import to LocalMachine\My requires Windows.'
    }

    $pfxPath = [string]$Certificate.PfxFullChain
    if ([string]::IsNullOrEmpty($pfxPath) -or -not (Test-Path -LiteralPath $pfxPath)) {
        throw ('Certificate PFX not found at ''{0}''.' -f $pfxPath)
    }

    $importParams = @{
        FilePath          = $pfxPath
        CertStoreLocation = 'Cert:\LocalMachine\My'
        Exportable        = $true
        ErrorAction       = 'Stop'
    }
    if ($null -ne $Certificate.PSObject.Properties['PfxPass'] -and $null -ne $Certificate.PfxPass) {
        $importParams['Password'] = $Certificate.PfxPass
    }

    $imported = Import-PfxCertificate @importParams
    $thumbprint = [string]$imported.Thumbprint

    Write-TUACMEEventLog -EventId 1011 -EntryType Information -Message ('Certificate for {0} imported to LocalMachine\My (thumbprint {1}).' -f $Certificate.MainDomain, $thumbprint)
    return $thumbprint
}
