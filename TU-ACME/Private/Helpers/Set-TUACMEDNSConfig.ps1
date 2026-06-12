function Set-TUACMEDNSConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PluginName,

        [Parameter(Mandatory = $true)]
        [hashtable]$PluginArgs
    )

    $config = Get-TUACMEConfig

    # Every plugin argument is treated as a credential and stored as keyless
    # ConvertFrom-SecureString (DPAPI, machine-bound) ciphertext (AC-H.3);
    # only the plugin name stays plaintext.
    $encryptedArgs = @()
    foreach ($name in ($PluginArgs.Keys | Sort-Object)) {
        $value = $PluginArgs[$name]
        if ($value -isnot [System.Security.SecureString]) {
            $value = ConvertTo-SecureString -String ([string]$value) -AsPlainText -Force
        }
        $encryptedArgs += [pscustomobject]@{
            Name           = [string]$name
            EncryptedValue = (ConvertFrom-SecureString -SecureString $value)
        }
    }

    $dns = [pscustomobject]@{
        PluginName = $PluginName
        Args       = $encryptedArgs
    }

    if ($null -ne $config.PSObject.Properties['Dns']) {
        $config.Dns = $dns
    }
    else {
        $config | Add-Member -MemberType NoteProperty -Name 'Dns' -Value $dns
    }

    Save-TUACMEConfig -Config $config
}
