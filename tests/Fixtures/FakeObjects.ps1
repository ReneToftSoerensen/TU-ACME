# Fake object builders for the Scripts test tier (UC-11.05).

function New-TUACMEFakeCertificate {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$MainDomain = 'www.example.com',

        [string]$Thumbprint = 'FAKE1234567890',

        [int]$DaysUntilExpiry = 60,

        [string]$PfxFullChain = 'C:\store\fullchain.pfx'
    )

    return [pscustomobject]@{
        MainDomain   = $MainDomain
        Thumbprint   = $Thumbprint
        NotAfter     = (Get-Date).AddDays($DaysUntilExpiry)
        PfxFullChain = $PfxFullChain
        PfxPass      = $null
    }
}
