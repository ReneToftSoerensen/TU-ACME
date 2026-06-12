function Invoke-TUACMEDryRun {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Operation,

        [object[]]$ArgumentList = @()
    )

    # The only staging entry point in the codebase: everything dry-run flows
    # through this try/finally so the session can never be left pointing at
    # staging, even when the operation throws (AC-B.3, AC-B.4). The swap
    # itself runs inside the try: Set-PAServer can succeed and Set-PAAccount
    # then fail (stale staging account id), and that half-swapped state must
    # still hit the finally restore.
    try {
        $null = Use-TUACMEStagingAccount
        $result = & $Operation @ArgumentList
        Write-TUACMEEventLog -EventId 1006 -EntryType Information -Message 'Dry-run operation completed against the staging account.'
        return $result
    }
    finally {
        $null = Use-TUACMEProdAccount
    }
}
