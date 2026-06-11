function Write-TUACMEEventLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$EventId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$EntryType,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not (Test-TUACMEIsWindows)) {
        Write-Verbose ('Event log skipped (non-Windows): [{0}] {1}' -f $EventId, $Message)
        return
    }

    # Logging must never break the caller (AC-A.1), so every failure here is
    # downgraded to a warning. Write-EventLog is unavailable on PowerShell 7;
    # the .NET EventLog type works on both editions.
    try {
        $source = 'TU-ACME'
        if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
            [System.Diagnostics.EventLog]::CreateEventSource($source, 'Application')
        }
        [System.Diagnostics.EventLog]::WriteEntry($source, $Message, $EntryType, $EventId)
    }
    catch {
        Write-Warning ('Failed to write event {0} to the Windows Event Log: {1}' -f $EventId, $_.Exception.Message)
    }
}
