# Shared bootstrap for all TU-ACME test files.
# Dot-source this at the top of every Describe block's BeforeAll.

$script:ModuleRoot = (Resolve-Path "$PSScriptRoot\..\TU-ACME").Path
$script:ModulePsd1 = Join-Path $script:ModuleRoot 'TU-ACME.psd1'

function Import-TUACMEModule {
    Remove-Module TU-ACME -ErrorAction SilentlyContinue -Force
    Import-Module $script:ModulePsd1 -Force -ErrorAction Stop
}

function Remove-TUACMEModule {
    Remove-Module TU-ACME -ErrorAction SilentlyContinue -Force
}

function New-TempTestDir {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) "TUACME-Test-$([System.Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Remove-TempTestDir {
    param([string] $Path)
    if ($Path -and (Test-Path $Path)) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function New-TempConfigEnv {
    $tmp = New-TempTestDir
    $env:_TUACME_TEST_PROGRAMDATA = Join-Path $tmp 'ProgramData'
    $env:_TUACME_TEST_LOCALAPPDATA = Join-Path $tmp 'LocalAppData'
    New-Item -ItemType Directory -Path $env:_TUACME_TEST_PROGRAMDATA -Force | Out-Null
    New-Item -ItemType Directory -Path $env:_TUACME_TEST_LOCALAPPDATA -Force | Out-Null
    return $tmp
}

# Helper: build a ConsoleKeyInfo object (PS 5.1 compatible)
function New-FakeKey {
    param(
        [System.ConsoleKey] $Key = [System.ConsoleKey]::Enter,
        [char]              $Char = [char]0
    )
    return New-Object System.ConsoleKeyInfo($Char, $Key, $false, $false, $false)
}

function New-FakeCharKey {
    param([char] $Char)
    $key = switch ($Char) {
        'Q' { [System.ConsoleKey]::Q } 'q' { [System.ConsoleKey]::Q }
        default { [System.ConsoleKey]::A }
    }
    return New-Object System.ConsoleKeyInfo($Char, $key, $false, $false, $false)
}

# Pre-load the module at file scope so InModuleScope works during Pester 5 discovery.
# Test files that call Import-TUACMEModule in BeforeAll will simply re-import it.
Import-TUACMEModule
