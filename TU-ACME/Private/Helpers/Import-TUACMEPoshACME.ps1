function Import-TUACMEPoshACME {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Posh-ACME resolves its store path at import; when it was already
        # loaded before TU-ACME set POSHACME_HOME, a force re-import is the
        # only way to point it at the machine store the SYSTEM renewal task
        # uses, instead of the importing user's %LOCALAPPDATA% store.
        [switch]$ForceStoreRebind
    )

    if (Get-Module -Name 'Posh-ACME') {
        if ($ForceStoreRebind) {
            try {
                Import-Module -Name 'Posh-ACME' -Global -Force -ErrorAction Stop
            }
            catch {
                Write-Warning ('Posh-ACME could not be re-imported after POSHACME_HOME changed; it may still use the per-user store: {0}' -f $_.Exception.Message)
            }
        }
        return $true
    }

    try {
        Import-Module -Name 'Posh-ACME' -Global -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}
