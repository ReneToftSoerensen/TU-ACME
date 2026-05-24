#Requires -Modules Pester

Describe 'UC-9.05 - Update-IISBindingForCert continues on per-binding failure' -Tag 'Scripts' {
    BeforeAll {
        # WebAdministration cmdlets are Windows-only. On Linux pwsh CI
        # we have to stub Import-Module + Get-WebBinding + Set-WebBinding
        # at global scope BEFORE dot-sourcing the plugin script, otherwise
        # the script-level Import-Module call throws on load.
        if (-not (Get-Command Get-WebBinding -ErrorAction SilentlyContinue)) {
            function global:Get-WebBinding { param($Protocol) }
            function global:Set-WebBinding { param($Name,$BindingInformation,$PropertyName,$Value) }
        }

        # Always shadow Import-Module so dot-sourcing the plugin script
        # does not try to actually load the WebAdministration module.
        # Note: -ErrorAction is a CommonParameter and must not be redeclared.
        function global:Import-Module {
            [CmdletBinding()]
            param(
                [Parameter(Position = 0, ValueFromPipeline = $true)] $Name,
                [switch] $Force
            )
        }

        $script:PluginPath = "$PSScriptRoot\..\..\TU-ACME\Scripts\Posh-ACME-IIS-Plugin.ps1"
        . $script:PluginPath
    }

    AfterAll {
        Remove-Item function:global:Get-WebBinding -ErrorAction SilentlyContinue
        Remove-Item function:global:Set-WebBinding -ErrorAction SilentlyContinue
        Remove-Item function:global:Import-Module  -ErrorAction SilentlyContinue
    }

    It 'continues to subsequent bindings when Set-WebBinding throws on one' {
        $old = 'OLDOLDOLDOLDOLDOLDOLD'
        $new = 'NEWNEWNEWNEWNEWNEWNEW'

        $bindings = @(
            [PSCustomObject]@{
                ItemXPath          = "/system.applicationHost/sites/site[@name='SiteA']"
                bindingInformation = '*:443:a.example.com'
                certificateHash    = $old
            },
            [PSCustomObject]@{
                ItemXPath          = "/system.applicationHost/sites/site[@name='SiteB']"
                bindingInformation = '*:443:b.example.com'
                certificateHash    = $old
            }
        )

        Mock Get-WebBinding { return $bindings }

        $script:_setCalls = 0
        Mock Set-WebBinding {
            $script:_setCalls++
            if ($script:_setCalls -eq 1) {
                throw 'Simulated rebind failure on first binding'
            }
        }

        { Update-IISBindingForCert -OldThumbprint $old -NewThumbprint $new -WarningAction SilentlyContinue } |
            Should -Not -Throw

        Assert-MockCalled Set-WebBinding -Times 2 -Scope It
    }
}
