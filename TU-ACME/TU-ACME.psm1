$Private = @(Get-ChildItem -Path "$PSScriptRoot\Private" -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue)
$Public  = @(Get-ChildItem -Path "$PSScriptRoot\Public"  -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($file in ($Private + $Public)) {
    try   { . $file.FullName }
    catch { Write-Error "Kunne ikke dot-source $($file.FullName): $_" }
}

Export-ModuleMember -Function $Public.BaseName
