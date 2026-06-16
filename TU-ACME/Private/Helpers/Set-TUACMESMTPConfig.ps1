function Set-TUACMESMTPConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Server,

        [int]$Port = 25,

        [string]$Username = '',

        # Optional: an internal relay is commonly unauthenticated, so a blank
        # password is valid and stores an empty EncryptedPassword (issue #15).
        [System.Security.SecureString]$Password
    )

    $config = Get-TUACMEConfig

    # ConvertFrom-SecureString without -Key uses DPAPI, so the stored
    # ciphertext is bound to this user on this machine by design (AC-H.2).
    # An empty SecureString (unauthenticated relay) is left unencrypted:
    # ConvertFrom-SecureString rejects an empty SecureString and would throw
    # otherwise (issue #15).
    $encryptedPassword = ''
    if ($null -ne $Password -and $Password.Length -gt 0) {
        $encryptedPassword = ConvertFrom-SecureString -SecureString $Password
    }

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
