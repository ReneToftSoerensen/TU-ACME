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
            # Note: Posh-ACME v4 has no Remove-PACertificate cmdlet —
            # only Remove-PAAccount exists. Per-cert deletion is done
            # by TU-ACME's own filesystem-based helper (the dashboard's
            # _Remove-TUACMECertDir), so there's nothing to proxy.
            # Revoke-PACertificate IS in Posh-ACME and sends a real
            # revocation request to the ACME server, so we proxy it.
            $cmds = @(
                'Get-PAAccount','New-PAAccount','Set-PAAccount',
                'Get-PAServer','Set-PAServer',
                'Get-PACertificate','New-PACertificate','Revoke-PACertificate',
                'Set-PAOrder',
                'Submit-Renewal',
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

                    # Strip [ValidateScript({...})] attributes. Real
                    # Posh-ACME parameters carry validators like
                    # [ValidateScript({ Test-ValidDirUrl $_ })] (one-liner)
                    # AND multi-line forms like
                    #   [ValidateScript({
                    #     Test-ValidFriendlyName $_ -ThrowOnFail
                    #   })]
                    # where Test-* are *private* functions inside the
                    # Posh-ACME module. ProxyCommand.Create copies the
                    # attribute verbatim into our proxy body — but our
                    # proxy lives in TU-ACME's scope, where those private
                    # validators are invisible, so parameter binding
                    # fails with "The term 'Test-Valid...' is not
                    # recognized". Posh-ACME's own function re-runs
                    # validation in ITS scope when we delegate via
                    # Posh-ACME\<cmd>, so stripping the proxy's copy is
                    # safe. Lazy .*? between `(` and `)]` handles both
                    # single-line and multi-line attribute bodies.
                    $body = $body -replace '(?s)\s*\[ValidateScript\(.*?\)\]\s*\r?\n', ''

                    # Strip Posh-ACME private type annotations on
                    # parameters. ProxyCommand.Create copies them
                    # verbatim, but types like [RevocationReasons]
                    # (an enum defined inside Posh-ACME) cannot be
                    # resolved from TU-ACME's scope - parameter
                    # binding throws "Unable to find type
                    # [RevocationReasons]" when the proxy is called,
                    # even if the user never passes -Reason.
                    # Stripping the annotation drops the proxy's
                    # parameter to [object]; the wrapped Posh-ACME
                    # cmdlet still has its own typed param block and
                    # re-validates inside its own scope where the
                    # type IS visible. Pattern matches a bare type
                    # annotation on its own line: "[TypeName]" or
                    # "[TypeName[]]" with no parentheses (so we
                    # don't accidentally strip [Parameter(...)],
                    # [ValidateSet(...)], [Alias(...)], etc.).
                    $privateTypes = @('RevocationReasons')
                    foreach ($t in $privateTypes) {
                        $body = $body -replace "(?m)^\s*\[$t\]\s*\r?\n", ''
                    }

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
