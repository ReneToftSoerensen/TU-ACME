function Write-EventLogEntry {
    param(
        [Parameter(Mandatory)] [int]    $EventId,
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('Information', 'Warning', 'Error')]
        [string] $EntryType = 'Information'
    )

    $logName = 'Application'
    $source  = 'TU-ACME'

    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
            New-EventLog -LogName $logName -Source $source -ErrorAction Stop
        }
        Write-EventLog -LogName $logName -Source $source `
            -EventId $EventId -EntryType $EntryType -Message $Message
    } catch {
        # Sil fejlen — Event Log er ikke kritisk for TUI-flow
    }
}
