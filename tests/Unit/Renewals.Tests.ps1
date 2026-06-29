#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' 'src' 'TU-ACME.psd1'
    Import-Module $modulePath -Force

    # Provide guarded stubs for Posh-ACME / IIS cmdlets on non-Windows CI runners
    # so that Mock can target them. These stubs are overridden by each test's Mock.
    if (-not (Get-Command Submit-Renewal -ErrorAction SilentlyContinue)) {
        function global:Submit-Renewal {
            [CmdletBinding()] param([switch]$AllOrders, [switch]$Force, [string]$Name, [string]$MainDomain)
        }
    }
    if (-not (Get-Command Get-PAOrder -ErrorAction SilentlyContinue)) {
        function global:Get-PAOrder { [CmdletBinding()] param([switch]$List, [switch]$Refresh, [string]$Name) }
    }
    if (-not (Get-Command Get-PACertificate -ErrorAction SilentlyContinue)) {
        function global:Get-PACertificate {
            [CmdletBinding()] param([string]$Order, [string]$MainDomain)
        }
    }
    if (-not (Get-Command Install-PACertificate -ErrorAction SilentlyContinue)) {
        function global:Install-PACertificate {
            [CmdletBinding()]
            param(
                [Parameter(ValueFromPipeline)][object]$InputObject,
                [string]$StoreLocation,
                [string]$StoreName
            )
        }
    }
    if (-not (Get-Command Get-IISServerManager -ErrorAction SilentlyContinue)) {
        function global:Get-IISServerManager { }
    }
}

# ---------------------------------------------------------------------------
# Update-IISCertificateBinding - SAN-match and old-thumbprint fallback
# ---------------------------------------------------------------------------
Describe 'Update-IISCertificateBinding' {
    It 'rebinds a binding matched by host header (SAN match)' {
        InModuleScope TU-ACME {
            Mock Get-IISSslBindings {
                @([pscustomobject]@{
                    SiteName           = 'Site1'
                    HostHeader         = 'a.example.com'
                    BindingInformation = '*:443:a.example.com'
                    Thumbprint         = 'aabbcc'
                })
            }
            Mock Get-IISBindingsByThumbprint { @() }
            Mock Set-IISBindingCertificate { }

            $result = Update-IISCertificateBinding -Thumbprint 'ddeeff' `
                -HostHeaders @('a.example.com') -StoreName 'WebHosting'

            $result.Rebound | Should -Be 1
            $result.Failed  | Should -Be 0
            Should -Invoke Set-IISBindingCertificate -Times 1
        }
    }

    It 'falls back to old-thumbprint match when no host-header binding is found' {
        InModuleScope TU-ACME {
            Mock Get-IISSslBindings { @() }
            Mock Get-IISBindingsByThumbprint {
                @([pscustomobject]@{
                    SiteName           = 'Site2'
                    HostHeader         = 'b.example.com'
                    BindingInformation = '*:443:b.example.com'
                    Thumbprint         = 'oldthumb'
                })
            }
            Mock Set-IISBindingCertificate { }

            $result = Update-IISCertificateBinding -Thumbprint 'newthumb' `
                -HostHeaders @() -OldThumbprint 'oldthumb' -StoreName 'WebHosting'

            $result.Rebound | Should -Be 1
            $result.Failed  | Should -Be 0
            Should -Invoke Set-IISBindingCertificate -Times 1
        }
    }

    It 'does not double-count a binding found by both SAN and old-thumbprint' {
        InModuleScope TU-ACME {
            $shared = [pscustomobject]@{
                SiteName           = 'Site3'
                HostHeader         = 'c.example.com'
                BindingInformation = '*:443:c.example.com'
                Thumbprint         = 'oldthumb'
            }
            Mock Get-IISSslBindings { @($shared) }
            Mock Get-IISBindingsByThumbprint { @($shared) }
            Mock Set-IISBindingCertificate { }

            $result = Update-IISCertificateBinding -Thumbprint 'newthumb' `
                -HostHeaders @('c.example.com') -OldThumbprint 'oldthumb' -StoreName 'WebHosting'

            # The binding must be targeted exactly once, not twice.
            $result.Targets  | Should -Be 1
            $result.Rebound  | Should -Be 1
            $result.Failed   | Should -Be 0
            Should -Invoke Set-IISBindingCertificate -Times 1
        }
    }

    It 'returns zero counts and makes no call when there are no matching bindings' {
        InModuleScope TU-ACME {
            Mock Get-IISSslBindings { @() }
            Mock Get-IISBindingsByThumbprint { @() }
            Mock Set-IISBindingCertificate { }

            $result = Update-IISCertificateBinding -Thumbprint 'newthumb' `
                -HostHeaders @('nomatching.example.com') -StoreName 'WebHosting'

            $result.Rebound | Should -Be 0
            $result.Failed  | Should -Be 0
            Should -Not -Invoke Set-IISBindingCertificate
        }
    }

    It 'counts a failed rebind in the Failed property and does not throw' {
        InModuleScope TU-ACME {
            Mock Get-IISSslBindings {
                @([pscustomobject]@{
                    SiteName           = 'Site4'
                    HostHeader         = 'd.example.com'
                    BindingInformation = '*:443:d.example.com'
                    Thumbprint         = 'old'
                })
            }
            Mock Get-IISBindingsByThumbprint { @() }
            Mock Set-IISBindingCertificate { throw 'IIS error' }
            Mock Write-Err { }

            $result = Update-IISCertificateBinding -Thumbprint 'new' `
                -HostHeaders @('d.example.com') -StoreName 'WebHosting'

            $result.Rebound | Should -Be 0
            $result.Failed  | Should -Be 1
        }
    }
}

# ---------------------------------------------------------------------------
# Invoke-RenewAll - Force switch and nothing-due no-op
# ---------------------------------------------------------------------------
Describe 'Invoke-RenewAll' {
    BeforeEach {
        InModuleScope TU-ACME {
            # Silence TUI output helpers
            Mock Write-Host { }
            Mock Write-Step { }
            Mock Write-Ok   { }
            Mock Write-Warn { }
            Mock Write-Info { }
            Mock Wait-UI    { }
            Mock Write-TUACMELog { }
            Mock Confirm-Prompt { $true }
        }
    }

    It 'passes -Force to Submit-Renewal when -Force is specified' {
        InModuleScope TU-ACME {
            Mock Get-PAOrdersList { @() }
            Mock Submit-Renewal { @() }

            Invoke-RenewAll -Force

            Should -Invoke Submit-Renewal -Times 1 `
                -ParameterFilter { $AllOrders -eq $true -and $Force -eq $true }
        }
    }

    It 'does not pass -Force to Submit-Renewal when -Force is omitted' {
        InModuleScope TU-ACME {
            Mock Get-PAOrdersList { @() }
            Mock Submit-Renewal { @() }

            Invoke-RenewAll

            Should -Invoke Submit-Renewal -Times 1 `
                -ParameterFilter { $AllOrders -eq $true -and $Force -ne $true }
        }
    }

    It 'does nothing (no Install or Rebind) when Submit-Renewal returns no certs' {
        InModuleScope TU-ACME {
            Mock Get-PAOrdersList { @() }
            Mock Submit-Renewal { @() }
            Mock Install-TUACMECertificate { }
            Mock Update-IISCertificateBinding { }

            Invoke-RenewAll

            Should -Not -Invoke Install-TUACMECertificate
            Should -Not -Invoke Update-IISCertificateBinding
        }
    }

    It 'installs and rebinds each renewed cert' {
        InModuleScope TU-ACME {
            $fakeCert = [pscustomobject]@{
                Thumbprint = 'AABBCCDDEEFF'
                Subject    = 'CN=x.example.com'
                MainDomain = 'x.example.com'
                AllSANs    = @('x.example.com')
            }
            Mock Get-PAOrdersList {
                @([pscustomobject]@{
                    Name        = 'x.example.com'
                    MainDomain  = 'x.example.com'
                    Identifiers = 'x.example.com'
                    Status      = 'valid'
                    CertThumb   = 'AABBCCDDEEFF'
                    # Provide both DateTime and ISO-8601 string to exercise
                    # ConvertTo-DateTime normalisation in the display path.
                    NotAfter    = [datetime]'2026-12-31T23:59:00'
                    RenewAfter  = '2026-09-01T00:00:00'
                })
            }
            Mock Submit-Renewal { @($fakeCert) }
            Mock Install-TUACMECertificate { }
            Mock Update-IISCertificateBinding {
                [pscustomobject]@{ Rebound = 1; Failed = 0; Targets = 1 }
            }

            Invoke-RenewAll

            Should -Invoke Install-TUACMECertificate -Times 1
            Should -Invoke Update-IISCertificateBinding -Times 1
        }
    }
}

# ---------------------------------------------------------------------------
# Invoke-RenewSingle - passes -Name to Submit-Renewal for the correct order
# ---------------------------------------------------------------------------
Describe 'Invoke-RenewSingle' {
    BeforeEach {
        InModuleScope TU-ACME {
            Mock Write-Host { }
            Mock Write-Step { }
            Mock Write-Ok   { }
            Mock Write-Warn { }
            Mock Write-Info { }
            Mock Write-Err  { }
            Mock Wait-UI    { }
            Mock Write-TUACMELog { }
            Mock Confirm-Prompt { $true }
        }
    }

    It 'passes -Name and -Force to Submit-Renewal for the specified order' {
        InModuleScope TU-ACME {
            $script:Config.CertStore = 'WebHosting'

            $fakeCert = [pscustomobject]@{
                Thumbprint = 'AABBCCDDEEFF'
                MainDomain = 'single.example.com'
                AllSANs    = @('single.example.com')
            }
            Mock Submit-Renewal { $fakeCert }
            Mock Install-TUACMECertificate { }
            Mock Update-IISCertificateBinding {
                [pscustomobject]@{ Rebound = 1; Failed = 0; Targets = 1 }
            }

            $order = [pscustomobject]@{
                Name        = 'single.example.com'
                MainDomain  = 'single.example.com'
                Status      = 'valid'
                CertThumb   = 'OLDTHUMB'
                Identifiers = 'single.example.com'
            }

            Invoke-RenewSingle -Order $order

            Should -Invoke Submit-Renewal -Times 1 `
                -ParameterFilter { $Name -eq 'single.example.com' -and $Force -eq $true }
        }
    }

    It 'does not call Submit-Renewal when the order status is invalid' {
        InModuleScope TU-ACME {
            Mock Submit-Renewal { }

            $order = [pscustomobject]@{
                Name        = 'bad.example.com'
                MainDomain  = 'bad.example.com'
                Status      = 'invalid'
                CertThumb   = ''
                Identifiers = 'bad.example.com'
            }

            Invoke-RenewSingle -Order $order

            Should -Not -Invoke Submit-Renewal
        }
    }
}

# ---------------------------------------------------------------------------
# Install-TUACMECertificate - delegates to Get-PACertificate | Install-PACertificate
# ---------------------------------------------------------------------------
Describe 'Install-TUACMECertificate' {
    It 'calls Install-PACertificate with the correct store' {
        InModuleScope TU-ACME {
            $fakeCert = [pscustomobject]@{ Thumbprint = 'ABCDEF' }
            Mock Get-PACertificate { $fakeCert }
            Mock Install-PACertificate { }

            Install-TUACMECertificate -OrderName 'test.example.com' -StoreName 'WebHosting'

            Should -Invoke Install-PACertificate -Times 1 `
                -ParameterFilter { $StoreLocation -eq 'LocalMachine' -and $StoreName -eq 'WebHosting' }
        }
    }
}
