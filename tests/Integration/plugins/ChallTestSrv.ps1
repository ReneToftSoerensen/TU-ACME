<#
    ChallTestSrv.ps1 - a Posh-ACME dns-01 plugin used *only* by the TU-ACME
    integration test. It satisfies ACME DNS-01 challenges against a Pebble test
    ACME server by writing/clearing TXT records through the management HTTP API
    of pebble-challtestsrv (https://github.com/letsencrypt/pebble), which Pebble
    is configured to use as its DNS server.

    This is test scaffolding, not a shipping TU-ACME feature: it lives under
    /tests and is loaded via the POSHACME_PLUGINS environment variable. The real
    default validation plugin for TU-ACME is WebSelfHost (HTTP-01).
#>

function Get-CurrentPluginType { 'dns-01' }

function Add-DnsTxt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$RecordName,
        [Parameter(Mandatory, Position = 1)]
        [string]$TxtValue,
        # Management API base URL of the pebble-challtestsrv instance.
        [string]$CTSMgmtUri = 'http://localhost:8055',
        [Parameter(ValueFromRemainingArguments)]
        $ExtraParams
    )
    # challtestsrv expects fully-qualified host names with a trailing dot.
    $body = @{ host = "$RecordName."; value = $TxtValue } | ConvertTo-Json -Compress
    Write-Verbose "Adding TXT record $RecordName via $CTSMgmtUri/set-txt"
    Invoke-RestMethod -Method Post -Uri "$CTSMgmtUri/set-txt" -Body $body -ContentType 'application/json' -ErrorAction Stop | Out-Null
}

function Remove-DnsTxt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$RecordName,
        [Parameter(Mandatory, Position = 1)]
        [string]$TxtValue,
        [string]$CTSMgmtUri = 'http://localhost:8055',
        [Parameter(ValueFromRemainingArguments)]
        $ExtraParams
    )
    $body = @{ host = "$RecordName." } | ConvertTo-Json -Compress
    Write-Verbose "Clearing TXT record $RecordName via $CTSMgmtUri/clear-txt"
    Invoke-RestMethod -Method Post -Uri "$CTSMgmtUri/clear-txt" -Body $body -ContentType 'application/json' -ErrorAction Stop | Out-Null
}

function Save-DnsTxt {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments)]
        $ExtraParams
    )
    # challtestsrv applies changes immediately; nothing to commit.
}
