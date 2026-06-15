function Get-TUACMESMTPConfig {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $config = Get-TUACMEConfig
    $smtpProperty = $config.PSObject.Properties['Smtp']
    if ($null -eq $smtpProperty -or $null -eq $smtpProperty.Value) {
        return $null
    }

    $smtp = $smtpProperty.Value
    $password = $null
    if (-not [string]::IsNullOrEmpty([string]$smtp.EncryptedPassword)) {
        $password = ConvertTo-SecureString -String $smtp.EncryptedPassword
    }

    return [pscustomobject]@{
        Server   = [string]$smtp.Server
        Port     = [int]$smtp.Port
        Username = [string]$smtp.Username
        Password = $password
    }
}
