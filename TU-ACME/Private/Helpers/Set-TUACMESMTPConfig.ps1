function Set-TUACMESMTPConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Server,

        [int]$Port = 25,

        [string]$Username = '',

        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$Password
    )

    $config = Get-TUACMEConfig

    # ConvertFrom-SecureString without -Key uses DPAPI, so the stored
    # ciphertext is machine-bound by design (AC-H.2).
    $encryptedPassword = ConvertFrom-SecureString -SecureString $Password

    $smtp = [pscustomobject]@{
        Server            = $Server
        Port              = $Port
        Username          = $Username
        EncryptedPassword = $encryptedPassword
    }

    if ($null -ne $config.PSObject.Properties['Smtp']) {
        $config.Smtp = $smtp
    }
    else {
        $config | Add-Member -MemberType NoteProperty -Name 'Smtp' -Value $smtp
    }

    Save-TUACMEConfig -Config $config
}
