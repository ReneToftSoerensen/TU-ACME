# UC-4.3: Vis detaljerede oplysninger om et valgt certifikat

**Kategori:** Dashboard  
**Prioritet:** Medium

## Mål
At se udvidede detaljer om ét specifikt certifikat uden at forlade TUI'en.

## Aktører
- Systemadministrator (Admin)
- Overvåger/Tekniker (ReadOnly)

## Prækonditioner
- Dashboard med certifikatliste er vist (UC-4.1).

## Hovedforløb
1. Brugeren navigerer op/ned i tabellen med piletasterne.
2. Det markerede certifikat fremhæves (f.eks. inverteret farve).
3. Brugeren trykker **Enter**.
4. En detalje-boks åbnes i TUI'en og viser:
   ```
   ===== Certifikatdetaljer =====
   Domæne:          eksempel.dk
   SAN:             www.eksempel.dk, mail.eksempel.dk
   Udsteder:        Let's Encrypt
   Udstedt:         2026-05-18
   Udloeber:        2026-08-18
   Thumbprint:      A1B2C3D4E5F6...
   Sti (certifikat): C:\...\cert.cer
   Sti (noegle):    C:\...\cert.key
   ACME-konto:      admin@eksempel.dk
   Seneste fornyelse: 2026-05-18 03:01:42
   ==============================
   [E] Eksporter  [I] Importer til Store  [ESC] Tilbage
   ```
5. Brugeren trykker ESC eller Q for at vende tilbage til listen.

## Postkonditioner
- Brugeren har set detaljerede oplysninger for det valgte certifikat.

## Alternative forløb
- Fra detaljevisningen kan brugeren starte UC-6.1, UC-6.2 eller UC-6.3 direkte.

## Tekniske noter
- PowerShell-kommando: `Get-PACertificate -MainDomain "eksempel.dk"`
- Thumbprint hentes via: `(Get-Item "Cert:\LocalMachine\My\<thumbprint>").Thumbprint`
