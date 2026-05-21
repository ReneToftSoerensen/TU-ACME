function Write-PALog {
    <#
    .SYNOPSIS
        Append one timestamped line per Posh-ACME cmdlet invocation to
        $env:ProgramData\TU-ACME\posh-acme.log.

        Parameter values are dumped verbatim except that keys matching
        the secret pattern (Key|Token|Secret|Password|Pass|Credential)
        are replaced with ***MASKED***. Nested PluginArgs hashtables
        are recursed. SecureString and PSCredential values get a typed
        placeholder instead of their plaintext.

        Logging never throws — if the log file can't be written, the
        wrapped cmdlet still runs.
    #>
    param(
        [Parameter(Mandatory)] [string] $Cmdlet,
        $BoundArgs = $null
    )

    try {
        $logDir = Join-Path $env:ProgramData 'TU-ACME'
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $logPath = Join-Path $logDir 'posh-acme.log'

        $argStr = _Format-PALogArgs -BoundArgs $BoundArgs
        $line   = '{0} {1} {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Cmdlet, $argStr

        Add-Content -Path $logPath -Value $line -Encoding UTF8
    } catch {
        # never block the wrapped cmdlet because of a log-write failure
    }
}

function _Format-PALogArgs {
    param($BoundArgs)

    if (-not $BoundArgs) { return '(no args)' }

    # IDictionary covers both [hashtable] and PSBoundParameters
    if ($BoundArgs -is [System.Collections.IDictionary]) {
        $keys = @($BoundArgs.Keys)
        if ($keys.Count -eq 0) { return '(no args)' }

        $parts = foreach ($k in ($keys | Sort-Object)) {
            "$k=$(_Format-PALogValue -Key $k -Value $BoundArgs[$k])"
        }
        return ($parts -join ' ')
    }

    return "$BoundArgs"
}

function _Format-PALogValue {
    param([string] $Key, $Value)

    if ($Key -match '(?i)Key|Token|Secret|Password|Pass|Credential') {
        return '***MASKED***'
    }
    if ($null -eq $Value) {
        return '$null'
    }
    if ($Value -is [securestring]) {
        return '***SECURESTRING***'
    }
    if ($Value -is [System.Management.Automation.PSCredential]) {
        return "PSCredential($($Value.UserName))"
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $sub = foreach ($k in ($Value.Keys | Sort-Object)) {
            "$k=$(_Format-PALogValue -Key $k -Value $Value[$k])"
        }
        return '{ ' + ($sub -join '; ') + ' }'
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return '[' + (($Value | ForEach-Object { _Format-PALogValue -Key $Key -Value $_ }) -join ', ') + ']'
    }
    return "$Value"
}
