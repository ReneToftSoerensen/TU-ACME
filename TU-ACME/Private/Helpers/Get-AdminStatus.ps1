function Get-AdminStatus {
    # $IsWindows is defined in PS 6+; PS 5.1 is always Windows so default to $true
    $onWindows = if (Test-Path variable:IsWindows) { $IsWindows } else { $true }
    if (-not $onWindows) { return $false }
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal] $identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
