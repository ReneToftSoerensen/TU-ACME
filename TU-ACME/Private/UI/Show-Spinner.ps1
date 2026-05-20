function Show-Spinner {
    param(
        [Parameter(Mandatory)] [string]      $Message,
        [Parameter(Mandatory)] [scriptblock] $ScriptBlock,
        [int] $Row = -1
    )

    $frames        = @('/', '-', '\', '|')
    $frameIndex    = 0
    $spinRow       = if ($Row -ge 0) { $Row } else { Get-ConsoleCursorTop }
    $script:_spinnerMessage = $Message

    Set-ConsoleCursorVisible -Visible $false

    $result    = $null
    $exception = $null

    $job = [System.Threading.Tasks.Task]::Run([System.Action]{
        try {
            $script:_spinnerResult = & $ScriptBlock
        } catch {
            $script:_spinnerException = $_
        }
        $script:_spinnerDone = $true
    })

    # Fallback: PS 5.1 does not have Task.Run, use synchronous execution with inline animation
    # Run the scriptblock in the foreground and animate at intervals
    $script:_spinnerDone      = $false
    $script:_spinnerResult    = $null
    $script:_spinnerException = $null

    # Since PS 5.1 does not have easy async, run the scriptblock synchronously
    # but show the spinner before and after each natural pause point
    Set-ConsoleCursorPos -X 0 -Y $spinRow
    Write-Host "  [ $($frames[0]) ] $($script:_spinnerMessage)" -NoNewline -ForegroundColor Cyan

    try {
        $result = & $ScriptBlock
    } catch {
        $exception = $_
    } finally {
        Set-ConsoleCursorPos -X 0 -Y $spinRow
        Write-Host (' ' * [Math]::Max((Get-ConsoleWidth) - 1, 79)) -NoNewline
        Set-ConsoleCursorPos -X 0 -Y $spinRow
        Set-ConsoleCursorVisible -Visible $true
    }

    if ($exception -ne $null) {
        throw $exception
    }
    return $result
}
