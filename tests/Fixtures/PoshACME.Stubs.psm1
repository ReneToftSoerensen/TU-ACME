# Stub Posh-ACME commands so Pester can mock them without the real module.
# Each stub throws so an unmocked call fails loudly in unit tests.

function Get-PAServer {
    [CmdletBinding()]
    param()
    throw 'Stub Get-PAServer called without a Pester mock.'
}

function Set-PAServer {
    [CmdletBinding()]
    param(
        [string]$DirectoryUrl
    )
    throw 'Stub Set-PAServer called without a Pester mock.'
}

function Get-PAAccount {
    [CmdletBinding()]
    param(
        [switch]$List
    )
    throw 'Stub Get-PAAccount called without a Pester mock.'
}

function Set-PAAccount {
    [CmdletBinding()]
    param(
        [string]$ID,
        [switch]$UseAltPluginEncryption
    )
    throw 'Stub Set-PAAccount called without a Pester mock.'
}

function New-PAAccount {
    [CmdletBinding()]
    param(
        [string[]]$Contact,
        [switch]$AcceptTOS
    )
    throw 'Stub New-PAAccount called without a Pester mock.'
}

function New-PACertificate {
    [CmdletBinding()]
    param(
        [string[]]$Domain,
        [string[]]$Contact,
        [switch]$AcceptTOS,
        [string]$Plugin,
        [hashtable]$PluginArgs
    )
    throw 'Stub New-PACertificate called without a Pester mock.'
}

function Get-PACertificate {
    [CmdletBinding()]
    param(
        [string]$MainDomain,
        [switch]$List
    )
    throw 'Stub Get-PACertificate called without a Pester mock.'
}

function Submit-Renewal {
    [CmdletBinding()]
    param(
        [string]$MainDomain,
        [switch]$Force,
        [switch]$NewKey
    )
    throw 'Stub Submit-Renewal called without a Pester mock.'
}

function Revoke-PACertificate {
    [CmdletBinding()]
    param(
        [string]$MainDomain,
        [switch]$Force
    )
    throw 'Stub Revoke-PACertificate called without a Pester mock.'
}

Export-ModuleMember -Function @(
    'Get-PAServer'
    'Set-PAServer'
    'Get-PAAccount'
    'Set-PAAccount'
    'New-PAAccount'
    'New-PACertificate'
    'Get-PACertificate'
    'Submit-Renewal'
    'Revoke-PACertificate'
)
