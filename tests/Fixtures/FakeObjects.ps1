# Fake objects for Pester tests. Domain-specific fakes added per UC.

function New-SequencedReadHostMock {
    param([Parameter(Mandatory)][string[]] $Answers)
    $script:_ReadHostAnswers = $Answers
    $script:_ReadHostIdx = 0
    Mock Read-Host -ModuleName TU-ACME {
        $i = $script:_ReadHostIdx
        $script:_ReadHostIdx = $i + 1
        if ($i -ge $script:_ReadHostAnswers.Count) {
            throw "Read-Host called more times ($($i+1)) than answers provided ($($script:_ReadHostAnswers.Count))"
        }
        return $script:_ReadHostAnswers[$i]
    }
}

function New-PAAccountFake {
    param([string] $Id = 'acct-fake-1', [string] $Contact = 'mailto:test@example.com')
    [PSCustomObject]@{ id = $Id; contact = @($Contact); status = 'valid' }
}

function Use-TUACMETempConfig {
    $script:_OriginalProgramData = $env:ProgramData
    $env:ProgramData = Join-Path ([System.IO.Path]::GetTempPath()) ("TU-ACME-test-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $env:ProgramData 'TU-ACME') -Force | Out-Null
}

function Restore-TUACMETempConfig {
    if (Test-Path $env:ProgramData) { Remove-Item -Path $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue }
    $env:ProgramData = $script:_OriginalProgramData
}
