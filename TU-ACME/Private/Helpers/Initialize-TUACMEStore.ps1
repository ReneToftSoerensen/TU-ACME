function Initialize-TUACMEStore {
    <#
    .SYNOPSIS
        Redirects Posh-ACME's data store from $env:LOCALAPPDATA\Posh-ACME
        (per-user) to $env:ProgramData\TU-ACME\Posh-ACME (machine-wide)
        so the interactive admin and the SYSTEM scheduled task read
        from the same location.

    .DESCRIPTION
        Posh-ACME's default store is $env:LOCALAPPDATA\Posh-ACME. For
        SYSTEM that resolves to C:\Windows\System32\config\systemprofile,
        a different folder from the admin's user profile - so a
        scheduled renewal running as SYSTEM cannot see the certs the
        admin issued interactively.

        Posh-ACME picks up the POSHACME_HOME environment variable on
        Import-Module to override the default. This function:

        1. Computes a machine-wide path under ProgramData.
        2. Creates it with Administrators + SYSTEM Full Control ACLs.
        3. Sets POSHACME_HOME in the current process (for the active
           TU-ACME session).
        4. When elevated, persists POSHACME_HOME machine-wide so
           future shells - and the SYSTEM task - inherit the same
           location without having to re-run TU-ACME.

        Must be called BEFORE any Posh-ACME cmdlet is touched, including
        the eager Import-Module Posh-ACME at the top of TU-ACME.psm1.
        Posh-ACME caches the resolved store path on first call and
        ignores later POSHACME_HOME changes within the same session.

        Account keys, cert files and order metadata are not DPAPI-
        encrypted by Posh-ACME, so they cross the user boundary as
        plain files once the folder ACL allows both principals.
        Plugin args (DNS API keys etc.) ARE DPAPI-bound by default;
        users who rely on credentialed DNS plugins must additionally
        run Set-PAAccount -UseAltPluginEncryption $true on each
        account so SYSTEM can decrypt them. Internal-CA / HTTP-01
        deployments do not need that step.
    #>
    [CmdletBinding()]
    param()

    $storeRoot = Join-Path $env:ProgramData 'TU-ACME\Posh-ACME'

    if (-not (Test-Path -LiteralPath $storeRoot)) {
        try {
            New-Item -ItemType Directory -Path $storeRoot -Force | Out-Null
        } catch {
            Write-Warning "TU-ACME: Could not create Posh-ACME store at $storeRoot - $($_.Exception.Message)"
        }
    }

    if ($script:OnWindows -and (Test-Path -LiteralPath $storeRoot)) {
        $isElevated = $false
        try {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object Security.Principal.WindowsPrincipal($identity)
            $isElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        } catch {}

        if ($isElevated) {
            try {
                $acl = Get-Acl -Path $storeRoot
                $admins = New-Object System.Security.Principal.SecurityIdentifier(
                    [System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
                $system = New-Object System.Security.Principal.SecurityIdentifier(
                    [System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
                $inherit = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
                $propagation = [System.Security.AccessControl.PropagationFlags]::None
                $allow = [System.Security.AccessControl.AccessControlType]::Allow

                $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $admins, 'FullControl', $inherit, $propagation, $allow)))
                $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $system, 'FullControl', $inherit, $propagation, $allow)))

                Set-Acl -Path $storeRoot -AclObject $acl
            } catch {
                # Best-effort: $env:ProgramData inheritance already
                # grants Administrators + SYSTEM access on a default
                # Windows install, so Posh-ACME usually works without
                # this explicit ACL. Swallow and continue.
            }
        }
    }

    $env:POSHACME_HOME = $storeRoot

    if ($script:OnWindows) {
        try {
            $existing = [Environment]::GetEnvironmentVariable('POSHACME_HOME', 'Machine')
            if ($existing -ne $storeRoot) {
                [Environment]::SetEnvironmentVariable('POSHACME_HOME', $storeRoot, 'Machine')
            }
        } catch {
            # SetEnvironmentVariable at Machine scope requires
            # elevation. Non-elevated callers still get the
            # per-process value above; the machine value is just
            # not refreshed.
        }
    }

    return $storeRoot
}
