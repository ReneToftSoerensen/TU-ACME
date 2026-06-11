@{
    RootModule           = 'TU-ACME.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'abeca80b-aa7e-476b-9997-413bb7b01e37'
    Author               = 'TU-ACME maintainers'
    CompanyName          = 'Fragt'
    Copyright            = '(c) Fragt. All rights reserved.'
    Description          = 'TUI wrapper around Posh-ACME for an internal corporate ACME CA.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @('Start-TUACME')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags = @('ACME', 'Certificates', 'Posh-ACME', 'Windows')
        }
    }
}
