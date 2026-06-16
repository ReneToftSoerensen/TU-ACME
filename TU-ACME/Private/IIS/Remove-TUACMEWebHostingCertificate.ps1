function Remove-TUACMEWebHostingCertificate {
    <#
    .SYNOPSIS
    Deletes a certificate from Cert:\LocalMachine\WebHosting (UC-9.03).

    .DESCRIPTION
    Removes a superseded certificate after a successful renewal rebind. The
    delete is best-effort: IIS may still hold a handle to the cert, so a failure
    is logged as a warning (event 2001) and reported via the return value rather
    than thrown — the next renewal sweep retries.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Thumbprint
    )

    if (-not (Test-TUACMEIsWindows)) {
        return $false
    }
    if ([string]::IsNullOrEmpty($Thumbprint)) {
        return $false
    }

    $path = ('Cert:\LocalMachine\WebHosting\{0}' -f $Thumbprint)
    try {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force -ErrorAction Stop
        }
        return $true
    }
    catch {
        Write-TUACMEEventLog -EventId 2001 -EntryType Warning -Message ('Failed to delete old certificate {0} from the WebHosting store: {1}' -f $Thumbprint, $_.Exception.Message)
        return $false
    }
}
