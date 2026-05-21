function Initialize-PALogging {
    <#
    .SYNOPSIS
        Install logging proxies for every Posh-ACME cmdlet TU-ACME calls.

        For each cmdlet, [ProxyCommand]::Create generates a script-block
        wrapper that mirrors every parameter (named + positional + dynamic)
        and delegates to the module-qualified original (e.g.
        Posh-ACME\Get-PACertificate). We prepend a Write-PALog call at the
        top of the begin{} block so every invocation is recorded before
        the underlying cmdlet runs.

        Proxies are installed in the script scope of the TU-ACME module,
        so they only shadow the originals for callers inside TU-ACME.
        External callers of Posh-ACME (and Pester mocks at the cmdlet
        name level inside InModuleScope TU-ACME) still see the originals
        / the mock, respectively.

        Failures here never break module load — if Posh-ACME isn't
        installed or a single proxy can't be created, we skip silently.
    #>

    if (-not (Get-Module -ListAvailable -Name 'Posh-ACME')) { return }
    if (-not (Get-Module -Name 'Posh-ACME')) {
        try { Import-Module Posh-ACME -ErrorAction Stop } catch { return }
    }

    $cmds = @(
        'Get-PAAccount','New-PAAccount','Set-PAAccount',
        'Get-PAServer','Set-PAServer',
        'Get-PACertificate','New-PACertificate','Submit-Renewal',
        'Get-PAPlugin','Get-PAPluginArgs','Set-PAConfig'
    )

    foreach ($name in $cmds) {
        $original = Get-Command -Module Posh-ACME -Name $name -ErrorAction SilentlyContinue
        if (-not $original) { continue }

        try {
            $body = [System.Management.Automation.ProxyCommand]::Create($original)

            # Inject the log call at the top of the begin{} block. The
            # generated proxy has "begin\n{" so \s* matches the newline.
            $injection = "`r`n    try { Write-PALog -Cmdlet '$name' -BoundArgs `$PSBoundParameters } catch {}"
            $body = $body -replace '(begin\s*\{)', "`$1$injection"

            Set-Item -Path "function:script:$name" -Value $body
        } catch {
            # skip this cmdlet, leave the original visible
        }
    }
}
