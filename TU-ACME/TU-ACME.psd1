@{
    ModuleVersion     = '0.0.2'
    GUID              = '6F921BD1-01FD-4A14-B267-3B10108F0235'
    Author            = 'TU-ACME'
    CompanyName       = 'TU-ACME'
    Copyright         = '(c) TU-ACME. All rights reserved.'
    Description       = 'Terminal UI til administration af Posh-ACME ACME/Let''s Encrypt certifikater pa Windows'
    PowerShellVersion = '5.1'
    RootModule        = 'TU-ACME.psm1'
    FunctionsToExport = @('Start-TUACME')
    CmdletsToExport   = @()
    AliasesToExport   = @()
    VariablesToExport = @()
    RequiredModules   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('ACME', 'LetsEncrypt', 'TUI', 'Certificates', 'IIS', 'PoshACME')
            ProjectUri = 'https://github.com/renetoftsoerensen/tu-acme'
        }
    }
}
