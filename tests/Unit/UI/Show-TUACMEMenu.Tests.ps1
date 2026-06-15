BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')

    function script:New-NamedKey {
        param([System.ConsoleKey]$Key)
        New-Object System.ConsoleKeyInfo([char]0, $Key, $false, $false, $false)
    }
    function script:New-CharKey {
        param([char]$Char)
        New-Object System.ConsoleKeyInfo($Char, [System.ConsoleKey]::Oem2, $false, $false, $false)
    }
    function script:Set-KeyQueue {
        param([object[]]$Keys)
        $script:keyQueue = New-Object System.Collections.Queue
        foreach ($key in $Keys) { $script:keyQueue.Enqueue($key) }
    }
}

Describe 'Show-TUACMEMenu navigation (UC-4.01 / AC-C.1)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Write-Host { }
        Mock -ModuleName 'TU-ACME' Clear-Host { }
        Mock -ModuleName 'TU-ACME' Read-TUACMEKey { $script:keyQueue.Dequeue() }
    }

    It 'returns the first item on immediate Enter' {
        Set-KeyQueue @((New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMenu -Title 'Main' -Items @('One', 'Two', 'Three')
        }

        $result | Should -Be 0
    }

    It 'moves down with the down arrow' {
        Set-KeyQueue @((New-NamedKey DownArrow), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMenu -Title 'Main' -Items @('One', 'Two', 'Three')
        }

        $result | Should -Be 1
    }

    It 'wraps to the top when moving past the last item' {
        Set-KeyQueue @((New-NamedKey DownArrow), (New-NamedKey DownArrow), (New-NamedKey DownArrow), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMenu -Title 'Main' -Items @('One', 'Two', 'Three')
        }

        $result | Should -Be 0
    }

    It 'wraps to the bottom when moving up from the first item' {
        Set-KeyQueue @((New-NamedKey UpArrow), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMenu -Title 'Main' -Items @('One', 'Two', 'Three')
        }

        $result | Should -Be 2
    }

    It 'skips disabled items during navigation' {
        Set-KeyQueue @((New-NamedKey DownArrow), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMenu -Title 'Main' -Items @('One', 'Two', 'Three') -DisabledIndices @(1)
        }

        $result | Should -Be 2
    }

    It 'highlights the current selection with the DarkCyan background' {
        Set-KeyQueue @((New-NamedKey Enter))

        $null = InModuleScope 'TU-ACME' {
            Show-TUACMEMenu -Title 'Main' -Items @('One', 'Two')
        }

        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter {
            $Object -like '*One*' -and [string]$BackgroundColor -eq 'DarkCyan'
        }
    }

    It 'returns -1 when the menu is cancelled with Escape' {
        Set-KeyQueue @((New-NamedKey Escape))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMenu -Title 'Main' -Items @('One', 'Two')
        }

        $result | Should -Be (-1)
    }

    It 'throws when every item is disabled' {
        {
            InModuleScope 'TU-ACME' {
                Show-TUACMEMenu -Title 'Main' -Items @('One', 'Two') -DisabledIndices @(0, 1)
            }
        } | Should -Throw '*at least one enabled item*'
    }
}
