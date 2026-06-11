BeforeDiscovery {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $powerShellFiles = @(Get-ChildItem -Path $repoRoot -Recurse -File |
        Where-Object { @('.ps1', '.psm1', '.psd1') -contains $_.Extension })
}

Describe 'UTF-8 BOM on PowerShell files (UC-11.01 / AC-I.1)' -Tag 'Unit', 'CodeQuality' {
    It 'has a UTF-8 BOM: <_.Name>' -ForEach $powerShellFiles {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        $bytes.Length | Should -BeGreaterOrEqual 3 -Because 'every PowerShell file must start with a UTF-8 BOM'
        $bytes[0] | Should -Be 239
        $bytes[1] | Should -Be 187
        $bytes[2] | Should -Be 191
    }
}

Describe 'PowerShell 5.1 compatibility (UC-11.02 / AC-I.2)' -Tag 'Unit', 'CodeQuality' {
    It 'parses without errors: <_.Name>' -ForEach $powerShellFiles {
        $tokens = $null
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $_.FullName, [ref]$tokens, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty
    }

    It 'contains no PS7-only syntax: <_.Name>' -ForEach $powerShellFiles {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $_.FullName, [ref]$tokens, [ref]$parseErrors)

        $bannedTokenKinds = @(
            'QuestionQuestion'
            'QuestionQuestionEquals'
            'QuestionDot'
            'QuestionLBracket'
            'AndAnd'
            'OrOr'
        )
        $offendingTokens = @($tokens | Where-Object {
                $bannedTokenKinds -contains $_.Kind.ToString()
            })
        $offendingTokens | Should -BeNullOrEmpty

        $bannedAstTypes = @('TernaryExpressionAst', 'PipelineChainAst', 'UsingStatementAst')
        $offendingNodes = @($ast.FindAll({
                    param($node)
                    $bannedAstTypes -contains $node.GetType().Name
                }, $true))
        $offendingNodes | Should -BeNullOrEmpty

        $commands = @($ast.FindAll({
                    param($node)
                    $node.GetType().Name -eq 'CommandAst'
                }, $true))
        foreach ($command in $commands) {
            $name = $command.GetCommandName()
            $parameterNames = @($command.CommandElements |
                Where-Object { $_.GetType().Name -eq 'CommandParameterAst' } |
                ForEach-Object { $_.ParameterName })
            if ($name -eq 'ConvertFrom-Json') {
                $parameterNames | Should -Not -Contain 'AsHashtable'
            }
            if ($name -eq 'ForEach-Object') {
                $parameterNames | Should -Not -Contain 'Parallel'
            }
        }
    }
}

Describe 'Account bootstrap bottleneck (UC-2.01)' -Tag 'Unit', 'CodeQuality' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    }

    It 'only the Use-TUACME*Account functions call Set-PAServer or Set-PAAccount' {
        $modulePath = Join-Path $repoRoot 'TU-ACME'
        $allowedFileNames = @('Use-TUACMEProdAccount.ps1', 'Use-TUACMEStagingAccount.ps1')

        $moduleFiles = @()
        if (Test-Path -LiteralPath $modulePath) {
            $moduleFiles = @(Get-ChildItem -Path $modulePath -Recurse -File |
                Where-Object { @('.ps1', '.psm1') -contains $_.Extension })
        }

        foreach ($file in $moduleFiles) {
            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $file.FullName, [ref]$tokens, [ref]$parseErrors)
            $bottleneckCalls = @($ast.FindAll({
                        param($node)
                        if ($node.GetType().Name -ne 'CommandAst') { return $false }
                        $name = $node.GetCommandName()
                        ($null -ne $name) -and (@('Set-PAServer', 'Set-PAAccount') -contains $name)
                    }, $true))
            if ($bottleneckCalls.Count -gt 0) {
                $file.Name | Should -BeIn $allowedFileNames -Because (
                    '{0} must not call Set-PAServer or Set-PAAccount directly' -f $file.Name)
            }
        }
    }
}
