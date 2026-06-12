param(
    [bool]$SkipInitialize = $false
)

$privateScripts = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -Recurse -File | Sort-Object -Property FullName)
$publicScripts = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File | Sort-Object -Property FullName)

foreach ($script in ($privateScripts + $publicScripts)) {
    . $script.FullName
}

Export-ModuleMember -Function 'Start-TUACME'

if (-not $SkipInitialize) {
    try {
        Initialize-TUACMEEnvironment
    }
    catch {
        Write-Warning ('TU-ACME initialization failed: {0}' -f $_.Exception.Message)
    }
}
