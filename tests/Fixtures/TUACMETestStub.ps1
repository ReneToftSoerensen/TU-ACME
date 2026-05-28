# TU-ACME no-op dns-01 plugin used by the Invoke-OrderCertificate
# integration test. Posh-ACME 4.32's plugin loader only accepts
# plugins whose Get-CurrentPluginType returns 'dns-01' or 'http-01',
# so this stub declares 'dns-01' to be discoverable.
#
# PEBBLE_VA_ALWAYS_VALID=1 means Pebble accepts the challenge
# without ever hitting DNS, so the Add/Remove/Save bodies can be
# completely empty.

function Get-CurrentPluginType { 'dns-01' }

function Add-DnsTxt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $RecordName,

        [Parameter(Mandatory, Position = 1)]
        [string] $TxtValue,

        [string] $Dummy,

        [Parameter(ValueFromRemainingArguments)]
        $ExtraParams
    )
    # no-op
}

function Remove-DnsTxt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $RecordName,

        [Parameter(Mandatory, Position = 1)]
        [string] $TxtValue,

        [string] $Dummy,

        [Parameter(ValueFromRemainingArguments)]
        $ExtraParams
    )
    # no-op
}

function Save-DnsTxt {
    [CmdletBinding()]
    param(
        [string] $Dummy,

        [Parameter(ValueFromRemainingArguments)]
        $ExtraParams
    )
    # no-op
}
