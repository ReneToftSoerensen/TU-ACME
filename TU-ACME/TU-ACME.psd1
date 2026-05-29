@{
    RootModule           = 'TU-ACME.psm1'
    ModuleVersion        = '0.3.2'
    GUID                 = 'c8dde9f1-e457-4c98-a951-b85ba5750826'
    Author               = 'TU-ACME'
    CompanyName          = 'TU-ACME'
    Description          = 'Terminal UI for managing Posh-ACME ACME certificates against an internal corporate ACME CA on Windows'
    PowerShellVersion    = '5.1'
    RequiredModules      = @()
    FunctionsToExport    = @('Start-TUACME')
    CmdletsToExport      = @()
    AliasesToExport      = @()
    VariablesToExport    = @()
    PrivateData          = @{
        PSData = @{
            Tags = @('ACME','TUI','Certificates','IIS','PoshACME','InternalCA')
        }
    }
}
