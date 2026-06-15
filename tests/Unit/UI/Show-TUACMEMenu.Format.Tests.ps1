BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')

    function script:New-NamedKey {
        param([System.ConsoleKey]$Key)
        New-Object System.ConsoleKeyInfo([char]0, $Key, $false, $false, $false)
    }
    function script:Set-KeyQueue {
        param([object[]]$Keys)
        $script:keyQueue = New-Object System.Collections.Queue
        foreach ($key in $Keys) { $script:keyQueue.Enqueue($key) }
    }
}

Describe 'Show-TUACMEMenu format (UC-4.03 / AC-C.3, AC-C.4)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Write-Host { }
        Mock -ModuleName 'TU-ACME' Clear-Host { }
        Mock -ModuleName 'TU-ACME' Read-TUACMEKey { $script:keyQueue.Dequeue() }
    }

    It 'rejects menu titles longer than 79 characters' {
        {
            InModuleScope 'TU-ACME' {
                Show-TUACMEMenu -Title ('x' * 80) -Items @('One')
            }
        } | Should -Throw
    }

    It 'rejects empty menu titles' {
        {
            InModuleScope 'TU-ACME' {
                Show-TUACMEMenu -Title '' -Items @('One')
            }
        } | Should -Throw
    }

    It 'accepts a 79-character title' {
        Set-KeyQueue @((New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMenu -Title ('x' * 79) -Items @('One')
        }

        $result | Should -Be 0
    }

    It 'renders chrome in DarkCyan and items in Cyan' {
        Set-KeyQueue @((New-NamedKey Enter))

        $null = InModuleScope 'TU-ACME' {
            Show-TUACMEMenu -Title 'Main menu' -Items @('One', 'Two')
        }

        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter {
            $Object -eq 'Main menu' -and [string]$ForegroundColor -eq 'DarkCyan'
        }
        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter {
            $Object -like '*Two*' -and [string]$ForegroundColor -eq 'Cyan'
        }
    }

    It 'never uses a color outside Cyan/DarkCyan' {
        Set-KeyQueue @((New-NamedKey DownArrow), (New-NamedKey Enter))

        $null = InModuleScope 'TU-ACME' {
            Show-TUACMEMenu -Title 'Main menu' -Items @('One', 'Two', 'Three') -DisabledIndices @(1)
        }

        Should -Invoke -ModuleName 'TU-ACME' Write-Host -Times 0 -Exactly -ParameterFilter {
            ($null -ne $ForegroundColor -and @('Cyan', 'DarkCyan') -notcontains [string]$ForegroundColor) -or
            ($null -ne $BackgroundColor -and @('Cyan', 'DarkCyan') -notcontains [string]$BackgroundColor)
        }
    }
}
