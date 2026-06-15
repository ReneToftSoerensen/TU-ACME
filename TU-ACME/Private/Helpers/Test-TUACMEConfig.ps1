function Test-TUACMEConfig {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Config,

        [bool]$RequireAccountIds = $true,

        [switch]$ThrowOnInvalid
    )

    $requiredFields = @('ContactEmail', 'ProdDirectoryUrl', 'StagingDirectoryUrl')
    if ($RequireAccountIds) {
        $requiredFields += @('ProdAccountId', 'StagingAccountId')
    }

    $missingFields = @()
    foreach ($field in $requiredFields) {
        $property = $null
        if ($null -ne $Config) {
            $property = $Config.PSObject.Properties[$field]
        }
        if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            $missingFields += $field
        }
    }

    if ($missingFields.Count -gt 0) {
        if ($ThrowOnInvalid) {
            throw ('TU-ACME configuration is missing required field(s): {0}' -f ($missingFields -join ', '))
        }
        return $false
    }

    # Set-PAServer only accepts full https URLs; catch a hand-edited config
    # (e.g. a Posh-ACME saved-server short name) here with a clear message
    # instead of deep inside the account bootstrap.
    foreach ($urlField in @('ProdDirectoryUrl', 'StagingDirectoryUrl')) {
        $url = [string]$Config.PSObject.Properties[$urlField].Value
        if ($url -notlike 'https://*') {
            if ($ThrowOnInvalid) {
                throw ('TU-ACME configuration field {0} must be a full https:// directory URL, got ''{1}''.' -f $urlField, $url)
            }
            return $false
        }
    }

    return $true
}
