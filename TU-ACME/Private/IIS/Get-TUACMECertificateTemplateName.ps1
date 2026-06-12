function Get-TUACMECertificateTemplateName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Certificate
    )

    # AD CS stamps the template in extension 1.3.6.1.4.1.311.21.7 (v2) or
    # 1.3.6.1.4.1.311.20.2 (v1). Non-AD CS certs have neither; return blank.
    $templateOids = @('1.3.6.1.4.1.311.21.7', '1.3.6.1.4.1.311.20.2')

    foreach ($extension in @($Certificate.Extensions)) {
        if ($null -eq $extension -or $null -eq $extension.Oid) {
            continue
        }
        if ($templateOids -notcontains [string]$extension.Oid.Value) {
            continue
        }

        try {
            $formatted = [string]$extension.Format($false)
        }
        catch {
            continue
        }

        if ($formatted -match 'Template=([^,\(]+)') {
            return $Matches[1].Trim()
        }
        if (-not [string]::IsNullOrWhiteSpace($formatted)) {
            return $formatted.Trim()
        }
    }

    return ''
}
