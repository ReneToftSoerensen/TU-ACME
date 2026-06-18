BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Bootstrap.ps1')

    function script:Set-MenuQueue {
        param([int[]]$Selections)
        $script:menuQueue = New-Object System.Collections.Queue
        foreach ($selection in $Selections) { $script:menuQueue.Enqueue($selection) }
    }
    function script:Set-ReadHostQueue {
        param([string[]]$Answers)
        $script:readHostQueue = New-Object System.Collections.Queue
        foreach ($answer in $Answers) { $script:readHostQueue.Enqueue($answer) }
    }
}

Describe 'Get-TUACMEOrderDomain quick selection (issue #21)' -Tag 'Unit' {
    BeforeEach {
        $script:menuQueue = New-Object System.Collections.Queue
        $script:readHostQueue = New-Object System.Collections.Queue

        Mock -ModuleName 'TU-ACME' Get-TUACMEKnownName {
            @(
                [pscustomobject]@{ Name = 'web01.corp.local'; Source = 'FQDN' }
                [pscustomobject]@{ Name = 'WEB01'; Source = 'Hostname' }
                [pscustomobject]@{ Name = 'intranet.corp.local'; Source = 'IIS host header' }
            )
        }
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { $script:menuQueue.Dequeue() }
        Mock -ModuleName 'TU-ACME' Read-Host { $script:readHostQueue.Dequeue() }
    }

    It 'returns just the CN when the operator picks a name then finishes SANs' {
        # CN = index 0 (FQDN); SAN menu = Done (last item: 3 candidates left -> +manual+done = index 3)
        Set-MenuQueue @(0, 3)

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)' })

        $result.Count | Should -Be 1
        $result[0] | Should -Be 'web01.corp.local'
    }

    It 'adds a picked SAN and then finishes' {
        # CN = index 0 (FQDN); SAN list now has WEB01, intranet, manual, done.
        # Pick index 0 (WEB01) -> then SAN list has intranet, manual, done -> pick done (index 2).
        Set-MenuQueue @(0, 0, 2)

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)' })

        $result.Count | Should -Be 2
        $result[0] | Should -Be 'web01.corp.local'
        $result[1] | Should -Be 'WEB01'
    }

    It 'adds multiple SANs in selection order' {
        # CN = 0 (FQDN). SAN1 list: WEB01(0), intranet(1), manual(2), done(3) -> pick WEB01(0).
        # SAN2 list: intranet(0), manual(1), done(2) -> pick intranet(0).
        # SAN3 list: manual(0), done(1) -> pick done(1).
        Set-MenuQueue @(0, 0, 0, 1)

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)' })

        $result | Should -Be @('web01.corp.local', 'WEB01', 'intranet.corp.local')
    }

    It 'returns an empty array when the CN menu is cancelled (Esc)' {
        Set-MenuQueue @(-1)

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)' })

        $result.Count | Should -Be 0
    }

    It 'finishes SAN selection when the SAN menu is cancelled (Esc)' {
        # CN = index 1 (Hostname); SAN menu Esc (-1) -> finish with CN only.
        Set-MenuQueue @(1, -1)

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)' })

        $result.Count | Should -Be 1
        $result[0] | Should -Be 'WEB01'
    }

    It 'lets the operator type a manual CN, then finishes' {
        # CN = manual (last item index 3); type a name; SAN list has all 3
        # known candidates -> SAN Done is index 4 (3 candidates + manual + done).
        Set-MenuQueue @(3, 4)
        Set-ReadHostQueue @('typed.corp.local')

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)' })

        $result.Count | Should -Be 1
        $result[0] | Should -Be 'typed.corp.local'
    }

    It 'lets the operator type a manual SAN' {
        # CN = 0; SAN1 list: WEB01(0), intranet(1), manual(2), done(3) -> manual(2);
        # type 'extra.corp.local'; SAN2 list back to 3 candidates -> done(3).
        Set-MenuQueue @(0, 2, 3)
        Set-ReadHostQueue @('extra.corp.local')

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)' })

        $result | Should -Be @('web01.corp.local', 'extra.corp.local')
    }

    It 'ignores a manual SAN that duplicates an already-selected name' {
        # CN = 0 (web01.corp.local); manual SAN typed equal to CN (case-insensitive) is dropped.
        Set-MenuQueue @(0, 2, 3)
        Set-ReadHostQueue @('WEB01.CORP.LOCAL')

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)' })

        $result.Count | Should -Be 1
        $result[0] | Should -Be 'web01.corp.local'
    }
}

Describe 'Get-TUACMEOrderDomain manual fallback (no known names)' -Tag 'Unit' {
    BeforeEach {
        $script:readHostQueue = New-Object System.Collections.Queue

        Mock -ModuleName 'TU-ACME' Get-TUACMEKnownName { @() }
        Mock -ModuleName 'TU-ACME' Show-TUACMEMenu { throw 'Show-TUACMEMenu should not be called when there are no known names.' }
        Mock -ModuleName 'TU-ACME' Read-Host { $script:readHostQueue.Dequeue() }
    }

    It 'returns an empty array when the FQDN is left blank' {
        Set-ReadHostQueue @('')

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)' })

        $result.Count | Should -Be 0
    }

    It 'defaults the SAN to the first DNS label when Enter is pressed' {
        Set-ReadHostQueue @('host.corp.local', '')

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)' })

        $result | Should -Be @('host.corp.local', 'host')
    }

    It 'skips the SAN when the operator answers "-"' {
        Set-ReadHostQueue @('host.corp.local', '-')

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)' })

        $result.Count | Should -Be 1
        $result[0] | Should -Be 'host.corp.local'
    }

    It 'overrides the default SAN with a typed value' {
        Set-ReadHostQueue @('host.corp.local', 'alias')

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)' })

        $result | Should -Be @('host.corp.local', 'alias')
    }

    It 'de-dupes a single-label FQDN to one name' {
        Set-ReadHostQueue @('host', '')

        $result = @(InModuleScope 'TU-ACME' { Get-TUACMEOrderDomain -Prompt 'FQDN to order (CN)' })

        $result.Count | Should -Be 1
        $result[0] | Should -Be 'host'
    }
}
