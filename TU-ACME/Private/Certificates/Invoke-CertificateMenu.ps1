function Invoke-CertificateMenu {
    <#
    .SYNOPSIS
        Certificate sub-menu — order, dry-run order (staging), or open
        the certificate dashboard.
    .DESCRIPTION
        Renders a Show-Menu loop with the four certificate actions.
        Pass -ShowOrder to skip straight to the order flow (used by
        the main menu hotkey).
    #>
    [CmdletBinding()]
    param([switch] $ShowOrder)

    if ($ShowOrder) {
        Invoke-OrderCertificate
        return
    }

    $title   = 'Certificates'
    $options = @(
        '1. Order new certificate',
        '2. Dry-run order (staging)',
        '3. Certificate Dashboard',
        'B. Back'
    )

    while ($true) {
        $sel = Show-Menu -Title $title -Options $options
        switch ($sel) {
            0 { Invoke-OrderCertificate }
            1 { Invoke-DryRunOrder }
            2 { Invoke-CertificateDashboard }
            3 { return }
            -1 { return }
            default { return }
        }
    }
}
