<#
    UI.ps1 - On-screen interface helpers for the TU-ACME TUI.

    This is a TUI: Write-Host is the correct output channel here (banner, menus,
    coloured status). Data-returning helpers elsewhere emit objects, not host text.
#>

function Show-Banner {
    # ASCII banner intentionally omitted for now; subtitle line only.
    Clear-Host
    Write-Host 'TU-ACME' -ForegroundColor Cyan
    Write-Host '  A Text User Interface for Posh-ACME on Windows (PowerShell 7)' -ForegroundColor Cyan
    Write-Host ''
}

function Write-Sep {
    param([string]$Title = '', [int]$Width = 108)
    if ($Title) {
        $line = ('-' * [Math]::Max(0, [int](($Width - $Title.Length - 2) / 2)))
        Write-Host ("{0} {1} {0}" -f $line, $Title) -ForegroundColor DarkCyan
    } else {
        Write-Host ('-' * $Width) -ForegroundColor DarkCyan
    }
}

function Write-Step {
    param([string]$Text)
    Write-Host ''
    Write-Host $Text -ForegroundColor Cyan
    Write-Sep
}

function Write-Ok   { param([string]$Message) Write-Host "[OK]   $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Err  { param([string]$Message) Write-Host "[ERR]  $Message" -ForegroundColor Red }
function Write-Info { param([string]$Message) Write-Host "[i]    $Message" -ForegroundColor DarkGray }

function Read-MenuChoice {
    param(
        [string]$Prompt = 'Choice',
        [string[]]$ValidKeys = @()
    )
    while ($true) {
        $line = Read-Host $Prompt
        if (-not $line) { continue }
        $key = $line.Trim().ToUpper()
        if ($ValidKeys -and ($key -notin $ValidKeys)) {
            Write-Warn "Invalid choice. Valid: $($ValidKeys -join ', ')"
            continue
        }
        return $key
    }
}

function Confirm-Prompt {
    param([string]$Prompt = 'Confirm?', [switch]$DefaultYes)
    $hint = if ($DefaultYes) { '[Y/n]' } else { '[y/N]' }
    $answer = Read-Host "$Prompt $hint"
    if ($DefaultYes) { return $answer.Trim().ToLower() -ne 'n' }
    return $answer.Trim().ToLower() -eq 'y'
}

function Wait-UI {
    param([string]$Message = 'Press Enter to continue...')
    Read-Host $Message | Out-Null
}
