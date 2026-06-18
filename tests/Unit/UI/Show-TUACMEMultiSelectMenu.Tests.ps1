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

Describe 'Show-TUACMEMultiSelectMenu selection' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Write-Host { }
        Mock -ModuleName 'TU-ACME' Clear-Host { }
        Mock -ModuleName 'TU-ACME' Read-TUACMEKey { $script:keyQueue.Dequeue() }
    }

    It 'returns an empty array when nothing is selected on Enter' {
        Set-KeyQueue @((New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick' -Items @('One', 'Two', 'Three')
        }

        @($result).Count | Should -Be 0
    }

    It 'returns the first item after Space then Enter' {
        Set-KeyQueue @((New-NamedKey Spacebar), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick' -Items @('One', 'Two', 'Three')
        }

        @($result) | Should -Be @(0)
    }

    It 'returns multiple selected indices sorted' {
        Set-KeyQueue @((New-NamedKey Spacebar), (New-NamedKey DownArrow), (New-NamedKey Spacebar), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick' -Items @('One', 'Two', 'Three')
        }

        @($result) | Should -Be @(0, 1)
    }

    It 'deselects an item when toggled twice' {
        Set-KeyQueue @((New-NamedKey Spacebar), (New-NamedKey Spacebar), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick' -Items @('One', 'Two', 'Three')
        }

        @($result).Count | Should -Be 0
    }

    It 'returns $null when cancelled with Escape' {
        Set-KeyQueue @((New-NamedKey Escape))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick' -Items @('One', 'Two', 'Three')
        }

        $result | Should -Be $null
    }

    It 'pre-checks items from PreSelectedIndices' {
        Set-KeyQueue @((New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick' -Items @('One', 'Two', 'Three') -PreSelectedIndices @(1)
        }

        @($result) | Should -Be @(1)
    }

    It 'skips disabled items during navigation' {
        # Down from the first enabled item lands on the third (index 2), so Space
        # there selects index 2.
        Set-KeyQueue @((New-NamedKey DownArrow), (New-NamedKey Spacebar), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick' -Items @('One', 'Two', 'Three') -DisabledIndices @(1)
        }

        @($result) | Should -Be @(2)
    }

    It 'ignores a disabled item that is supplied via PreSelectedIndices' {
        Set-KeyQueue @((New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick' -Items @('One', 'Two', 'Three') -DisabledIndices @(1) -PreSelectedIndices @(1)
        }

        @($result).Count | Should -Be 0
    }

    It 'narrows the visible list while filtering' {
        # 'two' matches only the second item, which becomes the only selectable
        # row; Space then Enter returns index 1.
        $keys = @((New-CharKey '/'))
        foreach ($char in 'two'.ToCharArray()) { $keys += (New-CharKey $char) }
        $keys += @((New-NamedKey Spacebar), (New-NamedKey Enter))
        Set-KeyQueue $keys

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick' -Items @('Alpha', 'Two', 'Three')
        }

        @($result) | Should -Be @(1)
    }

    It 'keeps a selection made before filtering after Escaping the filter' {
        # Select index 0, filter to something it would hide, Escape to restore the
        # full list, then confirm; the earlier selection survives.
        Set-KeyQueue @(
            (New-NamedKey Spacebar),
            (New-CharKey '/'),
            (New-CharKey 't'),
            (New-NamedKey Escape),
            (New-NamedKey Enter)
        )

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick' -Items @('Alpha', 'Two', 'Three')
        }

        @($result) | Should -Be @(0)
    }

    It 'selects all visible enabled items with a' {
        Set-KeyQueue @((New-CharKey 'a'), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMultiSelectMenu -Title 'Pick' -Items @('One', 'Two', 'Three') -DisabledIndices @(1)
        }

        @($result) | Should -Be @(0, 2)
    }

    It 'throws when every item is disabled' {
        {
            InModuleScope 'TU-ACME' {
                Show-TUACMEMultiSelectMenu -Title 'Pick' -Items @('One', 'Two') -DisabledIndices @(0, 1)
            }
        } | Should -Throw '*at least one enabled item*'
    }
}
