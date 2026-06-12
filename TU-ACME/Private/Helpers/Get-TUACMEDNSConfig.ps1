function Get-TUACMEDNSConfig {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $config = Get-TUACMEConfig
    $dnsProperty = $config.PSObject.Properties['Dns']
    if ($null -eq $dnsProperty -or $null -eq $dnsProperty.Value) {
        return $null
    }

    $dns = $dnsProperty.Value
    $pluginArgs = @{}
    foreach ($arg in @($dns.Args)) {
        $pluginArgs[[string]$arg.Name] = ConvertTo-SecureString -String ([string]$arg.EncryptedValue)
    }

    return [pscustomobject]@{
        PluginName = [string]$dns.PluginName
        PluginArgs = $pluginArgs
    }
}
