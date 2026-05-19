function Show-Spinner {
    param(
        [Parameter(Mandatory)] [string]      $Message,
        [Parameter(Mandatory)] [scriptblock] $ScriptBlock,
        [int] $Row = -1
    )

    $frames        = @('/', '-', '\', '|')
    $frameIndex    = 0
    $spinRow       = if ($Row -ge 0) { $Row } else { [Console]::CursorTop }
    $script:_spinnerMessage = $Message

    try { [Console]::CursorVisible = $false } catch {}

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

    # Fallback: PS 5.1 har ikke Task.Run, brug synkron kørsel med inline animation
    # Kør scriptblock i forgrunden og animer i perioder
    $script:_spinnerDone      = $false
    $script:_spinnerResult    = $null
    $script:_spinnerException = $null

    # Siden PS 5.1 ikke har nem async, kør scriptblock synkront
    # men vis spinner foer og efter hvert naturligt pause-punkt
    [Console]::SetCursorPosition(0, $spinRow)
    Write-Host "  [ $($frames[0]) ] $($script:_spinnerMessage)" -NoNewline -ForegroundColor Cyan

    try {
        $result = & $ScriptBlock
    } catch {
        $exception = $_
    } finally {
        [Console]::SetCursorPosition(0, $spinRow)
        Write-Host (' ' * [Math]::Max([Console]::WindowWidth - 1, 79)) -NoNewline
        [Console]::SetCursorPosition(0, $spinRow)
        try { [Console]::CursorVisible = $true } catch {}
    }

    if ($exception -ne $null) {
        throw $exception
    }
    return $result
}
