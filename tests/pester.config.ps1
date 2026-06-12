# Returns the shared Pester configuration for the TU-ACME test suite.
$configuration = New-PesterConfiguration
$configuration.Run.Path = $PSScriptRoot
$configuration.Filter.Tag = @('Unit')
$configuration.Output.Verbosity = 'Detailed'
return $configuration
