# TU-ACME test stub plugin used only by the DNS-PERSIST-01
# integration test. Every operation is a no-op.
#
# Posh-ACME 4.32's plugin loader (Private/Import-PluginDetail.ps1)
# only accepts plugins whose Get-CurrentPluginType returns one of
# 'dns-01' or 'http-01'. Plugins returning anything else are
# dropped with "sent unrecognized challenge type" and never become
# available. So even though this stub stands in for the persist
# flavor, it has to declare 'dns-01' to be discoverable.
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
