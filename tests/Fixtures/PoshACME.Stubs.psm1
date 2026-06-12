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
    param()
    throw 'Stub Get-PAAccount called without a Pester mock.'
}

function Set-PAAccount {
    [CmdletBinding()]
    param(
        [string]$ID
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

Export-ModuleMember -Function @(
    'Get-PAServer'
    'Set-PAServer'
    'Get-PAAccount'
    'Set-PAAccount'
    'New-PAAccount'
)
