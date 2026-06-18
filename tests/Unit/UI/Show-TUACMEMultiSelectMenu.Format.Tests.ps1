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

Describe 'Show-TUACMEMultiSelectMenu format' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Write-Host { }
        Mock -ModuleName 'TU-ACME' Clear-Host { }
        Mock -ModuleName 'TU-ACME' Read-TUACMEKey { $script:keyQueue.Dequeue() }
    }

    It 'rejects menu titles longer than 79 characters' {
        {
            InModuleScope 'TU-ACME' {
                Show-TUACMEMultiSelectMenu -Title ('x' * 80) -Items @('One')
            }
        } | Should -Throw
    }

    It 'rejects empty menu titles' {
        {
            InModuleScope 'TU-ACME' {
                Show-TUACMEMultiSelectMenu -Title '' -Items @('One')
            }
        } | Should -Throw
    }

    It 'accepts a 79-character title' {
        Set-KeyQueue @((New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title ('x' * 79) -Items @('One')
        }

        @($result).Count | Should -Be 0
    }

    It 'renders the title and footer in DarkCyan' {
        Set-KeyQueue @((New-NamedKey Enter))

        $null = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick names' -Items @('One', 'Two')
        }

        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter {
            $Object -eq 'Pick names' -and [string]$ForegroundColor -eq 'DarkCyan'
        }
        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter {
            $Object -like 'Arrows move*' -and [string]$ForegroundColor -eq 'DarkCyan'
        }
    }

    It 'renders an unselected non-current checkbox row in plain Cyan' {
        Set-KeyQueue @((New-NamedKey Enter))

        $null = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick names' -Items @('One', 'Two')
        }

        # The second item is neither current nor selected: '  [ ] Two' in Cyan.
        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter {
            $Object -like '  [[] []]*Two*' -and [string]$ForegroundColor -eq 'Cyan'
        }
    }

    It 'highlights the current checkbox row as Cyan on a DarkCyan background' {
        Set-KeyQueue @((New-NamedKey Enter))

        $null = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick names' -Items @('One', 'Two')
        }

        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter {
            $Object -like '> [[] []]*One*' -and [string]$ForegroundColor -eq 'Cyan' -and `
                [string]$BackgroundColor -eq 'DarkCyan'
        }
    }

    It 'renders the selected checkbox with an x marker' {
        Set-KeyQueue @((New-NamedKey Spacebar), (New-NamedKey Enter))

        $null = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick names' -Items @('One', 'Two')
        }

        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter {
            $Object -like '> [[]x[]]*One*' -and [string]$ForegroundColor -eq 'Cyan' -and `
                [string]$BackgroundColor -eq 'DarkCyan'
        }
    }

    It 'renders disabled checkbox rows in DarkCyan' {
        Set-KeyQueue @((New-NamedKey Enter))

        $null = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick names' -Items @('One', 'Two') -DisabledIndices @(1)
        }

        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter {
            $Object -like '*Two*' -and [string]$ForegroundColor -eq 'DarkCyan'
        }
    }

    It 'never uses a color outside Cyan/DarkCyan' {
        Set-KeyQueue @((New-NamedKey Spacebar), (New-NamedKey DownArrow), (New-NamedKey Enter))

        $null = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick names' -Items @('One', 'Two', 'Three') -DisabledIndices @(1)
        }

        Should -Invoke -ModuleName 'TU-ACME' Write-Host -Times 0 -Exactly -ParameterFilter {
            ($null -ne $ForegroundColor -and @('Cyan', 'DarkCyan') -notcontains [string]$ForegroundColor) -or
            ($null -ne $BackgroundColor -and @('Cyan', 'DarkCyan') -notcontains [string]$BackgroundColor)
        }
    }
}
