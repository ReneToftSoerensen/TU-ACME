function Initialize-PALogging {
    <#
    .SYNOPSIS
        Install logging proxies for every Posh-ACME cmdlet TU-ACME calls,
        and emit an [init] line so the log file always exists after module
        load even when proxy installation skips for some reason.
    #>

    $installed = @()
    $skipped   = @()
    $reason    = 'OK'

    try {
        # Posh-ACME should already be imported by TU-ACME.psm1's eager
        # import at the top of module load. If it isn't, fall back to
        # importing it here — but on PS 5.1 this nested-scope import
        # is less reliable, so we surface the situation in the [init]
        # line so it's easier to diagnose.
        if (-not (Get-Module -ListAvailable -Name 'Posh-ACME')) {
            $reason = 'Posh-ACME not installed on this machine'
        } elseif (-not (Get-Module -Name 'Posh-ACME')) {
            try {
                Import-Module Posh-ACME -ErrorAction Stop
            } catch {
                $reason = "Import-Module Posh-ACME failed: $($_.Exception.Message)"
            }
        }

        if ($reason -eq 'OK') {
            # Verified against the Posh-ACME v4 FunctionsToExport list.
            # Note: Set-PAConfig does NOT exist in v4 — there is no native
            # post-renewal hook. The IIS rebind runs from
            # Invoke-RenewalBackground.ps1 after Submit-Renewal completes.
            $cmds = @(
                'Get-PAAccount','New-PAAccount','Set-PAAccount',
                'Get-PAServer','Set-PAServer',
                'Get-PACertificate','New-PACertificate','Submit-Renewal',
                'Get-PAPlugin','Get-PAPluginArgs'
            )

            foreach ($name in $cmds) {
                $original = Get-Command -Module Posh-ACME -Name $name -ErrorAction SilentlyContinue
                if (-not $original) {
                    $skipped += "${name}(not-in-Posh-ACME)"
                    continue
                }

                try {
                    $body = [System.Management.Automation.ProxyCommand]::Create($original)

                    # ProxyCommand.Create generates an unqualified
                    # GetCommand('<name>',...) for function-typed commands.
                    # Since Posh-ACME ships functions, the unqualified
                    # lookup resolves back to *us* once our proxy is
                    # installed -> infinite recursion. Inject the module
                    # prefix so the wrapped lookup hits Posh-ACME's real
                    # function.
                    $body = $body -replace "\.GetCommand\('$name'", ".GetCommand('Posh-ACME\$name'"

                    $injection = "`r`n    try { Write-PALog -Cmdlet '$name' -BoundArgs `$PSBoundParameters } catch {}"
                    $body = $body -replace '(begin\s*\{)', "`$1$injection"

                    Set-Item -Path "function:script:$name" -Value $body
                    $installed += $name
                } catch {
                    $skipped += "${name}(proxy-error:$($_.Exception.Message))"
                }
            }
        }
    } catch {
        $reason = "Initialize-PALogging threw: $($_.Exception.Message)"
    }

    # ALWAYS write an init line. The log file's existence is itself the
    # primary signal that the wiring is alive — if it's not on disk, the
    # module never ran Initialize-PALogging at all.
    try {
        Write-PALog -Cmdlet '[init]' -BoundArgs @{
            InstalledCount = $installed.Count
            SkippedCount   = $skipped.Count
            Installed      = if ($installed) { $installed -join ',' } else { '<none>' }
            Skipped        = if ($skipped)   { $skipped   -join ',' } else { '<none>' }
            Reason         = $reason
            PSVersion      = $PSVersionTable.PSVersion.ToString()
        }
    } catch {}
}
