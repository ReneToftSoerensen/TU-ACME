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

Describe 'Show-TUACMEMenu search (UC-4.02 / AC-C.2)' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName 'TU-ACME' Write-Host { }
        Mock -ModuleName 'TU-ACME' Clear-Host { }
        Mock -ModuleName 'TU-ACME' Read-TUACMEKey { $script:keyQueue.Dequeue() }

        $script:menuItems = @('Order certificate', 'Renew certificate', 'Exit')
    }

    It 'filters to matching items after / and search text' {
        Set-KeyQueue @((New-CharKey '/'), (New-CharKey 'r'), (New-CharKey 'e'), (New-CharKey 'n'), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' -Parameters @{ Items = $script:menuItems } {
            param($Items)
            Show-TUACMEMenu -Title 'Main' -Items $Items
        }

        $result | Should -Be 1
    }

    It 'matches case-insensitively' {
        Set-KeyQueue @((New-CharKey '/'), (New-CharKey 'R'), (New-CharKey 'E'), (New-CharKey 'N'), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' -Parameters @{ Items = $script:menuItems } {
            param($Items)
            Show-TUACMEMenu -Title 'Main' -Items $Items
        }

        $result | Should -Be 1
    }

    It 'shows the search buffer while searching' {
        Set-KeyQueue @((New-CharKey '/'), (New-CharKey 'r'), (New-NamedKey Enter))

        $null = InModuleScope 'TU-ACME' -Parameters @{ Items = $script:menuItems } {
            param($Items)
            Show-TUACMEMenu -Title 'Main' -Items $Items
        }

        Should -Invoke -ModuleName 'TU-ACME' Write-Host -ParameterFilter { $Object -like 'Search: r*' }
    }

    It 'navigates the filtered results with the arrows' {
        # 'certificate' matches the two cert items; down moves to the second.
        $keys = @((New-CharKey '/'))
        foreach ($char in 'cert'.ToCharArray()) { $keys += (New-CharKey $char) }
        $keys += @((New-NamedKey DownArrow), (New-NamedKey Enter))
        Set-KeyQueue $keys

        $result = InModuleScope 'TU-ACME' -Parameters @{ Items = $script:menuItems } {
            param($Items)
            Show-TUACMEMenu -Title 'Main' -Items $Items
        }

        $result | Should -Be 1
    }

    It 'cancels search with Escape and restores the full menu' {
        Set-KeyQueue @((New-CharKey '/'), (New-CharKey 'x'), (New-NamedKey Escape), (New-NamedKey DownArrow), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' -Parameters @{ Items = $script:menuItems } {
            param($Items)
            Show-TUACMEMenu -Title 'Main' -Items $Items
        }

        $result | Should -Be 1
    }

    It 'removes search characters with Backspace' {
        # 'z' matches nothing; backspace empties the buffer so all items match.
        Set-KeyQueue @((New-CharKey '/'), (New-CharKey 'z'), (New-NamedKey Backspace), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' -Parameters @{ Items = $script:menuItems } {
            param($Items)
            Show-TUACMEMenu -Title 'Main' -Items $Items
        }

        $result | Should -Be 0
    }

    It 'ignores Enter while no item matches the search' {
        Set-KeyQueue @((New-CharKey '/'), (New-CharKey 'z'), (New-NamedKey Enter), (New-NamedKey Escape), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' -Parameters @{ Items = $script:menuItems } {
            param($Items)
            Show-TUACMEMenu -Title 'Main' -Items $Items
        }

        $result | Should -Be 0
    }

    It 'treats wildcard metacharacters in the search buffer as literals' {
        # An unbalanced [ would throw from -like; plain substring match
        # must survive it and simply match nothing.
        Set-KeyQueue @((New-CharKey '/'), (New-CharKey '['), (New-NamedKey Backspace), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' -Parameters @{ Items = $script:menuItems } {
            param($Items)
            Show-TUACMEMenu -Title 'Main' -Items $Items
        }

        $result | Should -Be 0
    }

    It 'matches a literal * in item text instead of treating it as a wildcard' {
        Set-KeyQueue @((New-CharKey '/'), (New-CharKey '*'), (New-NamedKey Enter))

        $result = InModuleScope 'TU-ACME' {
            Show-TUACMEMenu -Title 'Main' -Items @('Plain item', 'Starred * item')
        }

        $result | Should -Be 1
    }
}
