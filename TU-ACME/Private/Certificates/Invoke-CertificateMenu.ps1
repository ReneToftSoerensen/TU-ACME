function Invoke-CertificateMenu {
    param([switch] $ShowOrder)

    if ($ShowOrder) {
        Invoke-OrderCertificate
        return
    }

    while ($true) {
        $options = @(
            '1. Certifikat-dashboard',
            '2. Bestil nyt certifikat',
            'B. Tilbage'
        )
        $sel = Show-Menu -Title 'Certifikater' -Options $options

        switch ($sel) {
            -1 { return }
            0  { Invoke-CertificateDashboard }
            1  { Invoke-OrderCertificate }
            2  { return }
        }
    }
}
