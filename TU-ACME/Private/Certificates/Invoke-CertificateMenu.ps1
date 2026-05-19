function Invoke-CertificateMenu {
    param([switch] $ShowOrder)

    if ($ShowOrder) {
        Invoke-OrderCertificate
        return
    }

    while ($true) {
        $options = @(
            '1. Certificate Dashboard',
            '2. Order new certificate',
            'B. Back'
        )
        $sel = Show-Menu -Title 'Certificates' -Options $options

        switch ($sel) {
            -1 { return }
            0  { Invoke-CertificateDashboard }
            1  { Invoke-OrderCertificate }
            2  { return }
        }
    }
}
