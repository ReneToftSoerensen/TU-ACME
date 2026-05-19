# Pester 5.x configuration for TU-ACME test suite.
# Usage: Invoke-Pester -Configuration (& "$PSScriptRoot\pester.config.ps1")

$cfg = New-PesterConfiguration

$cfg.Run.Path            = "$PSScriptRoot"
$cfg.Run.Exit            = $true
$cfg.Filter.ExcludeTag   = @('LiveExternal')   # ACME/SMTP/ACME-DNS live calls
$cfg.Output.Verbosity    = 'Detailed'
$cfg.TestResult.Enabled  = $true
$cfg.TestResult.OutputPath   = "$PSScriptRoot\..\TestResults\pester-results.xml"
$cfg.TestResult.OutputFormat = 'NUnitXml'
$cfg.CodeCoverage.Enabled    = $true
$cfg.CodeCoverage.Path       = "$PSScriptRoot\..\TU-ACME\**\*.ps1"
$cfg.CodeCoverage.OutputPath = "$PSScriptRoot\..\TestResults\coverage.xml"
$cfg.CodeCoverage.OutputFormat = 'JaCoCo'

return $cfg
