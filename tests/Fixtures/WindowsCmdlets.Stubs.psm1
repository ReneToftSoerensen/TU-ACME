# Stub Windows-only commands (PKI, ScheduledTasks, WebAdministration) so
# Pester can mock them on any platform. Each stub throws so an unmocked
# call fails loudly in unit tests.

function Import-PfxCertificate {
    [CmdletBinding()]
    param(
        [string]$FilePath,
        [string]$CertStoreLocation,
        [System.Security.SecureString]$Password,
        [switch]$Exportable
    )
    throw 'Stub Import-PfxCertificate called without a Pester mock.'
}

function Get-WebBinding {
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$Protocol
    )
    throw 'Stub Get-WebBinding called without a Pester mock.'
}

function Register-ScheduledTask {
    [CmdletBinding()]
    param(
        [string]$TaskName,
        [object]$Action,
        [object[]]$Trigger,
        [object]$Principal,
        [object]$Settings,
        [switch]$Force
    )
    throw 'Stub Register-ScheduledTask called without a Pester mock.'
}

function New-ScheduledTaskAction {
    [CmdletBinding()]
    param(
        [string]$Execute,
        [string]$Argument
    )
    throw 'Stub New-ScheduledTaskAction called without a Pester mock.'
}

function New-ScheduledTaskTrigger {
    [CmdletBinding()]
    param(
        [switch]$Once,
        [switch]$AtStartup,
        [datetime]$At,
        [timespan]$RepetitionInterval
    )
    throw 'Stub New-ScheduledTaskTrigger called without a Pester mock.'
}

function New-ScheduledTaskPrincipal {
    [CmdletBinding()]
    param(
        [string]$UserId,
        [string]$LogonType,
        [string]$RunLevel
    )
    throw 'Stub New-ScheduledTaskPrincipal called without a Pester mock.'
}

Export-ModuleMember -Function @(
    'Import-PfxCertificate'
    'Get-WebBinding'
    'Register-ScheduledTask'
    'New-ScheduledTaskAction'
    'New-ScheduledTaskTrigger'
    'New-ScheduledTaskPrincipal'
)
