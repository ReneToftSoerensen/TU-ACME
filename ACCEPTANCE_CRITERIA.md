# TU-ACME v2 — Acceptance Criteria

## A. Module Initialization & Bootstrap

### AC-A.1: Module imports without errors
- **Given** the TU-ACME module is present
- **When** `Import-Module TU-ACME`
- **Then** no errors are thrown, and all public cmdlets are available

### AC-A.2: First-run wizard triggers on missing config
- **Given** `%ProgramData%\TU-ACME\config.json` does not exist
- **When** `Start-TUACME` is run
- **Then** the first-run wizard launches automatically; module import only warns
  (never prompts), so AC-A.1 holds in non-interactive sessions

### AC-A.3: First-run wizard creates two accounts
- **Given** the first-run wizard completes
- **When** we query the Posh-ACME store
- **Then** exactly two accounts exist: one tagged "prod" and one tagged "staging"

### AC-A.4: Config file is persisted correctly
- **Given** the first-run wizard completes
- **When** the module is reimported
- **Then** the wizard does not trigger, and prod/staging URLs and account IDs are available

## B. Two-Account Model

### AC-B.1: `Use-TUACMEProdAccount` sets prod context
- **Given** `Use-TUACMEProdAccount` is called
- **When** we query the current Posh-ACME account
- **Then** the active account matches the prod account ID from config

### AC-B.2: `Use-TUACMEStagingAccount` sets staging context
- **Given** `Use-TUACMEStagingAccount` is called
- **When** we query the current Posh-ACME account
- **Then** the active account matches the staging account ID from config

### AC-B.3: Dry-run always uses staging
- **Given** a certificate order is initiated with the `-DryRun` flag
- **When** the order completes
- **Then** the account used was the staging account, and the cert appears in the staging store only

### AC-B.4: Dry-run restores prod on exit
- **Given** a dry-run operation completes (success or error)
- **When** we query the active Posh-ACME account
- **Then** the prod account is restored (even if an error occurred mid-run)

## C. TUI Menu System

### AC-C.1: Main menu is keyboard-navigable
- **Given** the main menu is displayed
- **When** arrow keys and Enter are used
- **Then** menu items are selected and invoked correctly

### AC-C.2: Menu search works with `/` key
- **Given** any menu is displayed
- **When** the `/` key is pressed and search text is entered
- **Then** matching menu items are highlighted and selectable

### AC-C.3: Menu titles are ≤79 characters
- **Given** any menu title in the codebase
- **When** the title is measured
- **Then** it does not exceed 79 characters

### AC-C.4: Colors are Cyan/DarkCyan only
- **Given** the TUI is rendered
- **When** color output is applied
- **Then** only Cyan and DarkCyan are used (no Red, Green, Yellow, etc.)

## D. Certificate Operations

### AC-D.1: Order certificate (prod)
- **Given** a valid domain and contact email are provided
- **When** a certificate order is initiated (without `-DryRun`)
- **Then** the certificate is ordered against the prod account and appears in the store

### AC-D.2: Order certificate (dry-run)
- **Given** a valid domain is provided
- **When** a certificate order is initiated with `-DryRun`
- **Then** the certificate is issued against staging, does not appear in the prod store, and prod context is restored

### AC-D.3: Renew certificate
- **Given** an existing certificate in the prod store
- **When** a renewal is triggered manually
- **Then** the certificate is renewed against the prod account

### AC-D.4: Revoke certificate
- **Given** an existing certificate in the prod store
- **When** revocation is requested
- **Then** the certificate is revoked and no longer valid

### AC-D.5: Force-renew with new key
- **Given** an existing certificate in the prod store
- **When** force-renew with `-NewKey` is requested
- **Then** a new key is generated and a new certificate is ordered

## E. Scheduled Renewal

### AC-E.1: Scheduled task is installable
- **Given** the installation script is run with admin privileges
- **When** the scheduled task creation option is selected
- **Then** a Windows Scheduled Task is created to run the renewal script hourly (or per policy)

### AC-E.2: Renewal script runs without user interaction
- **Given** the scheduled renewal task triggers
- **When** the renewal script executes
- **Then** it completes without prompting the user and logs to Event Log

### AC-E.3: Background renewal imports certs
- **Given** a certificate is renewed in the background
- **When** the renewal completes
- **Then** the certificate is imported to `LocalMachine\My` automatically

## F. Event Logging

### AC-F.1: Initialization logged (ID 1010)
- **Given** the module initializes for the first time
- **When** the first-run wizard completes
- **Then** Event Log entry ID 1010 is written (Information level)

### AC-F.2: Orders logged (ID 1003)
- **Given** a certificate order completes
- **When** the operation succeeds
- **Then** Event Log entry ID 1003 is written with the domain and thumbprint

### AC-F.3: Renewals logged (ID 1001)
- **Given** a certificate renewal completes
- **When** the operation succeeds
- **Then** Event Log entry ID 1001 is written with the domain and renewal details

### AC-F.4: Errors logged (ID 3xxx)
- **Given** an unrecoverable error occurs during any operation
- **When** the error is caught
- **Then** Event Log entry ID 3xxx is written (Error level) with context

## G. IIS Integration

### AC-G.1: IIS bindings are discoverable
- **Given** IIS is installed and running
- **When** the certificate dashboard loads
- **Then** existing HTTPS bindings are listed with their current certificates

### AC-G.2: IIS rebind succeeds
- **Given** a new certificate is ordered and imported
- **When** the IIS rebind is triggered for a binding
- **Then** the binding thumbprint is updated and IIS reloads

### AC-G.3: IIS rebind failure is recoverable
- **Given** an IIS rebind fails (e.g., binding in use)
- **When** the operation completes
- **Then** an Event Log warning (ID 2001) is logged, and renewal continues

## H. Configuration & Persistence

### AC-H.1: Config is loadable on reimport
- **Given** `config.json` exists in `%ProgramData%\TU-ACME\`
- **When** the module is imported
- **Then** all configuration (server URLs, account IDs, contact email) is loaded correctly

### AC-H.2: SMTP credentials are encrypted
- **Given** SMTP credentials are configured
- **When** they are stored in `config.json`
- **Then** they are encrypted via DPAPI and not readable as plaintext

### AC-H.3: DNS credentials are encrypted
- **Given** DNS plugin credentials are configured
- **When** they are stored in `config.json`
- **Then** they are encrypted via DPAPI and not readable as plaintext

## I. Code Quality

### AC-I.1: All `*.ps1`, `*.psm1`, `*.psd1` files have UTF-8 BOM
- **Given** any PowerShell file in the module
- **When** the file is examined
- **Then** the first three bytes are `EF BB BF` (UTF-8 BOM)

### AC-I.2: No PS7-only syntax in the codebase
- **Given** any PowerShell file in the module
- **When** it is parsed
- **Then** the syntax is valid on both Windows PowerShell 5.1 and PowerShell 7.2+

### AC-I.3: Pester suite passes (Unit tag)
- **Given** `Invoke-Pester -Tag Unit`
- **When** tests run
- **Then** all tests pass with green status

### AC-I.4: Pester suite passes (Integration tag)
- **Given** `Invoke-Pester -Tag Integration`
- **When** tests run against a real Posh-ACME store on disk
- **Then** all tests pass with green status

### AC-I.5: Pester suite passes (Scripts tag)
- **Given** `Invoke-Pester -Tag Scripts`
- **When** renewal and deploy scripts run against fake objects
- **Then** all tests pass with green status

## J. Operational Workflows

### AC-J.1: Operator can list certificates
- **Given** the TUI main menu is displayed
- **When** "Certificate Dashboard" is selected
- **Then** a list of all certificates (domain, expiry, thumbprint, IIS bindings) is displayed

### AC-J.2: Operator can order a new certificate
- **Given** the TUI main menu is displayed
- **When** "Order Certificate" is selected and domain/contact email are entered
- **Then** the certificate is ordered and appears in the dashboard

### AC-J.3: Operator can perform a dry-run
- **Given** the TUI main menu is displayed
- **When** "Dry-Run Order" is selected
- **Then** the order is placed against staging, and the prod environment is unchanged

### AC-J.4: Operator can view renewal status
- **Given** the TUI main menu is displayed
- **When** "Renewal Status" is selected
- **Then** a report of certificate ages and next renewal dates is displayed

---

## Traceability Matrix

| AC ID | Use Case | Priority | Status |
|-------|----------|----------|--------|
| AC-A.1 | UC-1.01-module-import | P0 | [x] |
| AC-A.2 | UC-1.02-first-run | P0 | [x] |
| AC-A.3 | UC-1.02-first-run | P0 | [x] |
| AC-A.4 | UC-1.02-first-run | P0 | [x] |
| AC-B.1 | UC-2.01-account-bootstrap | P0 | [x] |
| AC-B.2 | UC-2.01-account-bootstrap | P0 | [x] |
| AC-B.3 | UC-3.01-dry-run | P1 | [ ] |
| AC-B.4 | UC-3.01-dry-run | P1 | [ ] |
| AC-C.1 | UC-4.01-menu-navigation | P1 | [ ] |
| AC-C.2 | UC-4.02-menu-search | P1 | [ ] |
| AC-C.3 | UC-4.03-menu-format | P0 | [ ] |
| AC-C.4 | UC-4.03-menu-format | P0 | [ ] |
| AC-D.1 | UC-5.01-order-cert | P0 | [ ] |
| AC-D.2 | UC-5.02-order-dryrun | P1 | [ ] |
| AC-D.3 | UC-6.01-renew-cert | P1 | [ ] |
| AC-D.4 | UC-6.02-revoke-cert | P2 | [ ] |
| AC-D.5 | UC-6.03-force-renew | P2 | [ ] |
| AC-E.1 | UC-7.01-scheduled-task | P1 | [ ] |
| AC-E.2 | UC-7.02-renewal-script | P1 | [ ] |
| AC-E.3 | UC-7.02-renewal-script | P1 | [ ] |
| AC-F.1 | UC-8.01-event-logging | P1 | [ ] |
| AC-F.2 | UC-8.01-event-logging | P1 | [ ] |
| AC-F.3 | UC-8.01-event-logging | P1 | [ ] |
| AC-F.4 | UC-8.01-event-logging | P1 | [ ] |
| AC-G.1 | UC-9.01-iis-discover | P1 | [ ] |
| AC-G.2 | UC-9.02-iis-rebind | P1 | [ ] |
| AC-G.3 | UC-9.03-iis-recovery | P1 | [ ] |
| AC-H.1 | UC-10.01-config-persist | P0 | [x] |
| AC-H.2 | UC-10.02-smtp-encrypt | P1 | [ ] |
| AC-H.3 | UC-10.03-dns-encrypt | P1 | [ ] |
| AC-I.1 | UC-11.01-utf8-bom | P0 | [x] |
| AC-I.2 | UC-11.02-ps51-compat | P0 | [x] |
| AC-I.3 | UC-11.03-unit-tests | P0 | [x] |
| AC-I.4 | UC-11.04-integration-tests | P1 | [ ] |
| AC-I.5 | UC-11.05-script-tests | P1 | [ ] |
| AC-J.1 | UC-12.01-dashboard | P1 | [ ] |
| AC-J.2 | UC-5.01-order-cert | P0 | [ ] |
| AC-J.3 | UC-5.02-order-dryrun | P1 | [ ] |
| AC-J.4 | UC-12.02-renewal-status | P2 | [ ] |
