function Get-CertTemplateName {
    <#
    .SYNOPSIS
        Returns the AD CS certificate template name from an X509Certificate2,
        or '' when the cert has no template extension (e.g. non-AD-issued
        certs like Let's Encrypt or an external public CA).
    .DESCRIPTION
        AD CS stamps issued certs with one of two extensions:
          v1 — OID 1.3.6.1.4.1.311.20.2 — UTF8/BMPString of the template name
          v2 — OID 1.3.6.1.4.1.311.21.7 — SEQUENCE { templateOID, major, minor }
        v2 is the modern form; nearly every Server 2012+ AD CS deployment
        issues v2 templates. v1 is checked as a fallback for older CAs and
        manually-converted templates.

        AsnEncodedData.Format($false) is the path of least resistance:
        Windows already knows how to pretty-print these two specific OIDs.
        For v2 the formatted string looks like
            "Template=WebServer(1.3.6.1.4.1.311.21.8.<x>.<y>), Major Version Number=100, Minor Version Number=2"
        — we capture the human-readable name between '=' and '(' / ','.
        For v1 the formatted string is the template name verbatim.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $Certificate
    )

    if ($null -eq $Certificate -or $null -eq $Certificate.Extensions) {
        return ''
    }

    foreach ($oid in '1.3.6.1.4.1.311.21.7', '1.3.6.1.4.1.311.20.2') {
        $ext = $Certificate.Extensions | Where-Object { $_.Oid.Value -eq $oid } | Select-Object -First 1
        if (-not $ext) { continue }

        try {
            $asn = New-Object System.Security.Cryptography.AsnEncodedData $ext.Oid, $ext.RawData
            $formatted = $asn.Format($false)
            if ([string]::IsNullOrWhiteSpace($formatted)) { continue }

            if ($oid -eq '1.3.6.1.4.1.311.21.7') {
                if ($formatted -match 'Template\s*=\s*([^(,\r\n]+)') {
                    return $Matches[1].Trim()
                }
            } else {
                # v1: take the first non-empty line, strip Template= prefix if present.
                $line = ($formatted -split "[`r`n]") | Where-Object { $_.Trim() } | Select-Object -First 1
                if ($line) {
                    $line = $line.Trim()
                    if ($line -match '^Template\s*=\s*(.+)$') { return $Matches[1].Trim() }
                    return $line
                }
            }
        } catch {
            continue
        }
    }

    return ''
}
