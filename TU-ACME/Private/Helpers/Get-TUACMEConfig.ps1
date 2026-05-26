function Get-TUACMEConfig {
    $configPath = Join-Path $env:ProgramData 'TU-ACME\config.json'

    $defaults = [PSCustomObject]@{
        Version       = '0.2.0'
        Acme          = [PSCustomObject]@{
            ProdDirectoryUrl    = ''
            StagingDirectoryUrl = ''
            ContactEmail        = ''
            ProdAccountId       = ''
            StagingAccountId    = ''
            Initialized         = $false
            InitializedAt       = ''
        }
        ScheduledTask = [PSCustomObject]@{
            TaskName     = 'Posh-ACME-AutoRenewal'
            RunTime      = '03:00'
            RunAsAccount = 'SYSTEM'
        }
        Email         = [PSCustomObject]@{
            SmtpServer       = ''
            SmtpPort         = 587
            UseSsl           = $true
            UseAuth          = $true
            SenderAddress    = ''
            RecipientAddress = ''
        }
        Dashboard     = [PSCustomObject]@{
            WarnDaysThreshold    = 30
            DefaultSort          = 'ExpiryAscending'
            ShowDryRunsByDefault = $false
        }
        DNS           = [PSCustomObject]@{
            DefaultDnsSleep          = 120
            DefaultValidationTimeout = 60
            PersistentRecords        = $false
        }
    }

    if (-not (Test-Path $configPath)) {
        return $defaults
    }

    $loaded = $null
    try {
        $json   = Get-Content -Path $configPath -Raw -Encoding UTF8
        $loaded = $json | ConvertFrom-Json
    } catch {
        return $defaults
    }

    # Backfill missing properties on the loaded config so callers can
    # always read $cfg.Acme.ProdDirectoryUrl etc. without first probing
    # PSObject.Properties. A partial config.json (left over from a
    # half-completed first-run, an older schema version, or a manually
    # edited file) would otherwise blow up later with
    # "The property 'X' cannot be found on this object".
    Merge-TUACMEConfigDefaults -Target $loaded -Defaults $defaults
    return $loaded
}

function Merge-TUACMEConfigDefaults {
    param(
        [Parameter(Mandatory)] $Target,
        [Parameter(Mandatory)] $Defaults
    )
    foreach ($p in $Defaults.PSObject.Properties) {
        $name = $p.Name
        $defVal = $p.Value
        $hasIt  = $Target.PSObject.Properties.Match($name).Count -gt 0
        if (-not $hasIt) {
            # Property missing entirely: add it with the default value.
            $Target | Add-Member -NotePropertyName $name -NotePropertyValue $defVal -Force
            continue
        }
        $curVal = $Target.$name
        if ($defVal -is [PSCustomObject] -and $curVal -is [PSCustomObject]) {
            # Recurse so nested blocks (Acme, ScheduledTask, Email,
            # Dashboard, DNS) get the same backfill treatment.
            Merge-TUACMEConfigDefaults -Target $curVal -Defaults $defVal
        } elseif ($defVal -is [PSCustomObject] -and $null -eq $curVal) {
            # Nested block missing — replace with the full default block.
            $Target.$name = $defVal
        }
    }
}
