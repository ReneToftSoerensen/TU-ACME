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

    if ($missingFields.Count -eq 0) {
        return $true
    }

    if ($ThrowOnInvalid) {
        throw ('TU-ACME configuration is missing required field(s): {0}' -f ($missingFields -join ', '))
    }

    return $false
}
