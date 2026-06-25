#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' 'src' 'TU-ACME.psd1'
    Import-Module $modulePath -Force

    # Guard stubs for Posh-ACME cmdlets that may not be installed on CI.
    if (-not (Get-Command Submit-Renewal -ErrorAction SilentlyContinue)) {
        function global:Submit-Renewal { [CmdletBinding()] param([switch]$AllOrders, [switch]$Force) }
    }
    if (-not (Get-Command Get-PAOrder -ErrorAction SilentlyContinue)) {
        function global:Get-PAOrder { [CmdletBinding()] param([string]$Name, [switch]$List, [switch]$Refresh) }
    }
    if (-not (Get-Command Get-PACertificate -ErrorAction SilentlyContinue)) {
        function global:Get-PACertificate { [CmdletBinding()] param([string]$Order, [string]$MainDomain) }
    }
}

# Helper: build a minimal fake PACertificate object.
function New-FakeCert {
    param([string]$Thumbprint = 'AABBCCDD', [string[]]$SANs = @('test.example.com'))
    [pscustomobject]@{
        Thumbprint  = $Thumbprint
        Subject     = "CN=$($SANs[0])"
        MainDomain  = $SANs[0]
        AllSANs     = $SANs
        NotAfter    = (Get-Date).AddDays(60)
    }
}

Describe 'Invoke-RenewAll — Force flag threading' {

    BeforeEach {
        InModuleScope TU-ACME {
            # Silence interactive prompts.
            Mock Confirm-Prompt { $true }
            Mock Wait-UI { }
            Mock Write-Step { }
            Mock Write-Ok { }
            Mock Write-Info { }
            Mock Write-Err { }
            Mock Write-Warn { }
            Mock Write-Host { }
            Mock Write-TUACMELog { }

            # No orders by default — tests that need orders override this.
            Mock Get-PAOrdersList { @() }

            # Deploy helpers: succeed silently.
            Mock Install-TUACMECertificate { }
            Mock Update-IISCertificateBinding {
                [pscustomobject]@{ Rebound = 1; Failed = 0; Targets = 1 }
            }
            Mock Invoke-TUACMEPostDeployHook { $true }
        }
    }

    Context 'Normal run (no -Force)' {
        It 'calls Submit-Renewal -AllOrders without -Force' {
            InModuleScope TU-ACME {
                Mock Submit-Renewal { @() }

                Invoke-RenewAll

                Should -Invoke Submit-Renewal -Times 1 -ParameterFilter { $AllOrders -eq $true -and -not $Force }
            }
        }
    }

    Context 'Force run (-Force)' {
        It 'calls Submit-Renewal -AllOrders -Force' {
            InModuleScope TU-ACME {
                Mock Submit-Renewal { @() }

                Invoke-RenewAll -Force

                Should -Invoke Submit-Renewal -Times 1 -ParameterFilter { $AllOrders -eq $true -and $Force -eq $true }
            }
        }
    }

    Context 'Force run — post-renewal steps still execute' {
        It 'installs and rebinds for each renewed cert when -Force is used' {
            InModuleScope TU-ACME {
                $fakeCert = [pscustomobject]@{
                    Thumbprint = 'DEADBEEF01'
                    Subject    = 'CN=test.example.com'
                    MainDomain = 'test.example.com'
                    AllSANs    = @('test.example.com')
                    NotAfter   = (Get-Date).AddDays(60)
                }

                # Provide a matching order so SAN-lookup in Invoke-RenewAll succeeds.
                Mock Get-PAOrdersList {
                    @([pscustomobject]@{
                        Name        = 'test.example.com'
                        MainDomain  = 'test.example.com'
                        Identifiers = 'test.example.com'
                        Status      = 'valid'
                        CertThumb   = 'OLDTHUMB01'
                        NotAfter    = (Get-Date).AddDays(60)
                        RenewAfter  = (Get-Date).AddDays(30)
                    })
                }

                Mock Submit-Renewal { $fakeCert }

                Invoke-RenewAll -Force

                Should -Invoke Install-TUACMECertificate -Times 1
                Should -Invoke Update-IISCertificateBinding -Times 1
            }
        }
    }
}

Describe 'Get-RenewalScheduledTaskCommand — Force flag in argument line' {

    It 'does not include -Force when switch is absent' {
        InModuleScope TU-ACME {
            $result = Get-RenewalScheduledTaskCommand -TaskName 'TU-ACME-Test'
            $result.ActionCmd | Should -Not -Match '-Force'
        }
    }

    It 'includes -Force when switch is present' {
        InModuleScope TU-ACME {
            $result = Get-RenewalScheduledTaskCommand -TaskName 'TU-ACME-Test' -Force
            $result.ActionCmd | Should -Match '-Force'
        }
    }
}
