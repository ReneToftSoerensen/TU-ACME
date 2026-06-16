function Convert-TUACMEThumbprintToByte {
    <#
    .SYNOPSIS
    Converts a hex certificate thumbprint to a byte array (issue #16).

    .DESCRIPTION
    The IISAdministration provider expects a binding's certificateHash as a
    byte[], whereas TU-ACME carries thumbprints as uppercase hex strings.
    Strips any spaces or dashes, then converts each hex pair to a byte.
    #>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Thumbprint
    )

    $clean = ($Thumbprint -replace '[\s\-]', '')
    $bytes = for ($i = 0; $i -lt $clean.Length; $i += 2) {
        [System.Convert]::ToByte($clean.Substring($i, 2), 16)
    }

    # The comma stops PowerShell from unrolling the array on return.
    return , ([byte[]]$bytes)
}
