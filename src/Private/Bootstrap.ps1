<#
    Bootstrap.ps1 - Prerequisite assertions and shared-state initialisation.

    NOTE on portability: the module must import (and unit-test with mocks) on
    non-Windows CI runners. All Windows-only work is therefore gated behind
    Test-TUACMEOnWindows so that merely loading the module never throws.
#>

function Test-TUACMEOnWindows {
    # $IsWindows is an automatic variable in PowerShell 7.
    return [bool]$IsWindows
}

function Assert-TUACMEElevated {
    <#
        .SYNOPSIS
            Throws if the current session is not elevated (admin). Required for
            Install-PACertificate and IIS binding edits.
    #>
    if (-not (Test-TUACMEOnWindows)) { return }
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'TU-ACME must be run from an elevated (Administrator) PowerShell session.'
    }
}

function Assert-TUACMEModule {
    <#
        .SYNOPSIS
            Verifies Posh-ACME and IISAdministration are importable. Surfaces a
            clear, actionable message rather than a bare exception.
    #>
    if (-not (Test-TUACMEOnWindows)) { return }
    foreach ($name in @('Posh-ACME', 'IISAdministration')) {
        if (-not (Get-Module -ListAvailable -Name $name)) {
            throw ("Required module '{0}' is not installed. Install it for all users so " +
                   "both the interactive admin and the SYSTEM scheduled task can load it:`n" +
                   "  Install-Module -Name {0} -Scope AllUsers -Force") -f $name
        }
    }
    Import-Module Posh-ACME -ErrorAction Stop
}

function Set-TUACMEAcl {
    <#
        .SYNOPSIS
            Applies the ACL on the TU-ACME ProgramData root:
              Administrators : FullControl
              SYSTEM         : FullControl
              Users          : ReadAndExecute
            inherited to children.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-TUACMEOnWindows)) { return }
    if (-not $PSCmdlet.ShouldProcess($Path, 'Apply TU-ACME ACL')) { return }

    $acl = Get-Acl $Path
    # isProtected=$false keeps inheritance from the parent; preserveInheritance is
    # moot when not protected. Explicit (non-inherited) rules are cleared below so
    # the rules we add are the only explicit ACEs.
    $acl.SetAccessRuleProtection($false, $false)
    $acl.Access |
        Where-Object { -not $_.IsInherited } |
        ForEach-Object { [void]$acl.RemoveAccessRule($_) }

    $rules = @(
        [Security.AccessControl.FileSystemAccessRule]::new(
            'BUILTIN\Administrators', 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'),
        [Security.AccessControl.FileSystemAccessRule]::new(
            'NT AUTHORITY\SYSTEM', 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'),
        [Security.AccessControl.FileSystemAccessRule]::new(
            'BUILTIN\Users', 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    )
    foreach ($rule in $rules) { $acl.AddAccessRule($rule) }
    Set-Acl -Path $Path -AclObject $acl
}

function Initialize-TUACMEHome {
    <#
        .SYNOPSIS
            Ensures %ProgramData%\TU-ACME and its ACME store exist with the right
            ACL, then points POSHACME_HOME at the shared store (machine + process)
            so the admin and the SYSTEM scheduled task share one Posh-ACME store.

            Fixed path, no scope knob. No migration: whatever already lives in the
            store is used as-is.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    foreach ($dir in @($script:ProgramDataDir, $script:SharedACMEHome)) {
        if (-not (Test-Path $dir)) {
            if ($PSCmdlet.ShouldProcess($dir, 'Create directory')) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }
    }

    Set-TUACMEAcl -Path $script:ProgramDataDir

    if (Test-TUACMEOnWindows) {
        $current = [Environment]::GetEnvironmentVariable('POSHACME_HOME', 'Machine')
        if ($current -ne $script:SharedACMEHome -and
            $PSCmdlet.ShouldProcess('POSHACME_HOME (Machine)', "Set to $script:SharedACMEHome")) {
            try {
                [Environment]::SetEnvironmentVariable('POSHACME_HOME', $script:SharedACMEHome, 'Machine')
            } catch {
                Write-Warn "Could not set machine-wide POSHACME_HOME: $_"
            }
        }
        # Current process needs the value too (machine-scope changes don't
        # propagate to a running process).
        $env:POSHACME_HOME = $script:SharedACMEHome
        Import-Module Posh-ACME -Force -ErrorAction SilentlyContinue
    }
}
