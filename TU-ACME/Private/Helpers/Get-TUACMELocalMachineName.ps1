function Get-TUACMELocalMachineName {
    <#
    .SYNOPSIS
    Resolves the local machine's short hostname and fully qualified domain name.

    .DESCRIPTION
    Returns a single object with two properties:

    - HostName: the short / NetBIOS-style hostname of the machine.
    - Fqdn:     the fully qualified domain name, or an empty string when the
                machine is not domain-joined (or DNS cannot resolve an FQDN).

    The DNS lookups are wrapped so a transient resolution failure degrades to an
    empty FQDN rather than throwing; callers (Get-TUACMEKnownName) treat an empty
    FQDN as "no FQDN candidate to offer". A resolved name is only treated as an
    FQDN when it is dotted; a single-label answer just echoes the short hostname
    and is therefore not a distinct FQDN candidate.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $hostName = ''
    try {
        $hostName = [string][System.Net.Dns]::GetHostName()
    }
    catch {
        $hostName = ''
    }
    if ([string]::IsNullOrEmpty($hostName)) {
        $hostName = [string]$env:COMPUTERNAME
    }

    $fqdn = ''
    if (-not [string]::IsNullOrEmpty($hostName)) {
        try {
            $entry = [System.Net.Dns]::GetHostEntry($hostName)
            if ($null -ne $entry) {
                $fqdn = [string]$entry.HostName
            }
        }
        catch {
            $fqdn = ''
        }
    }

    # Only dotted names are real FQDNs; a single-label answer just echoes the
    # short hostname, which is already offered as the Hostname candidate.
    if ($fqdn.IndexOf('.') -lt 1) {
        $fqdn = ''
    }

    return [pscustomobject]@{
        HostName = $hostName
        Fqdn     = $fqdn
    }
}
