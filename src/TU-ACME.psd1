@{
    # Module manifest for TU-ACME
    RootModule        = 'TU-ACME.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b6f6d6f2-1c2e-4d8a-9d2a-2f4c2a9e7c10'
    Author            = 'ReneToftSoerensen'
    CompanyName       = 'ReneToftSoerensen'
    Copyright         = '(c) ReneToftSoerensen. All rights reserved.'
    Description       = 'TU-ACME - an interactive Simple-ACME/WACS-style terminal UI over Posh-ACME (4.x) for issuing and renewing certificates against an internal ACME CA, with IIS binding integration.'

    PowerShellVersion = '7.0'

    # NOTE: Posh-ACME (>= 4.x) and IISAdministration are required at runtime on the
    # target Windows/IIS hosts. They are intentionally NOT declared in RequiredModules
    # so the module remains importable (and unit-testable with mocks) on machines and
    # CI runners where IIS / Posh-ACME are not installed. Presence is asserted at
    # runtime by the bootstrap (see Private/Bootstrap.ps1).

    FunctionsToExport = @(
        'Start-TUACME',
        # Shared helpers called by PoshAcme-Renew.ps1 (ISSUE-02)
        'Install-TUACMECertificate',
        'Update-IISCertificateBinding',
        'Invoke-TUACMEPostDeployHook',
        'Get-AllPAAccounts',
        'Write-TUACMELog',
        'Get-IISSslBindings'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('ACME', 'Posh-ACME', 'IIS', 'TLS', 'Certificates', 'Windows')
            ProjectUri   = 'https://github.com/ReneToftSoerensen/TU-ACME'
            ExternalModuleDependencies = @('Posh-ACME', 'IISAdministration')
        }
    }
}
