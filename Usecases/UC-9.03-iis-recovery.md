# UC-9.03: IIS Rebind & Old-Cert Cleanup Failure Recovery

## Narrative

As an **automated system**, I want to **handle IIS rebind and old-certificate-cleanup failures gracefully**, so that **a renewal that issued a fresh certificate is never rolled back because a single binding refused to rebind or the old cert refused to delete**.

The IIS thin-layer flow has three post-ACME side effects that can each fail independently:

1. **Import into `Cert:\LocalMachine\WebHosting`** (UC-9.02) — if this fails, the rebind cannot proceed for that cert, and the failure is surfaced as a terminating error (the cert is still safely in the Posh-ACME store; the operator can retry the import from the menu).
2. **Rebind one or more bindings** (UC-9.02) — per-binding failure must **not** abort the renewal; the cert was already issued and other bindings should still get pointed at it.
3. **Delete the old cert from `Cert:\LocalMachine\WebHosting`** on renewal (this UC) — a deletion failure is logged as a warning but never aborts the renewal; the new cert is already serving traffic, and a stale old cert in the store is harmless until the next sweep.

Dry-run (UC-3.01) bypasses all three steps, so this UC's recovery logic only applies to production flows.

## Acceptance Criteria

- [x] If a rebind fails for a single binding, it is logged but does not abort renewal (UC-9.02)
- [x] Event Log entry ID 2001 (Warning) is written with binding details and error on per-binding rebind failure
- [x] If the old-cert delete fails after a successful renewal rebind, Event Log entry ID 2001 is written; renewal still reports success
- [x] Renewal script continues to the next certificate/binding after any of the failures above
- [x] Error message is clear (e.g., "binding is in use", "access denied", "cert in use by another binding")
- [x] Operator is notified of failed bindings and undeleted old certs via Event Log and dashboard
- [x] Failed bindings can be manually retried from the menu (UC-9.02)
- [x] Undeleted old certs can be cleaned up manually from the certificate dashboard

## Implementation Notes

- Each side effect is wrapped in its own try/catch at the operation level
- Errors are logged but do not propagate up the renewal chain — except for WebHosting import failure, which **does** propagate because the rebind cannot run without it
- Old-cert delete failure is non-fatal because IIS may still be holding a handle to the cert; the next renewal pass will retry
- Manual retry option available in the certificate dashboard for both "rebind" and "delete old cert"

## Test Coverage

**Unit:** Mock rebind failure and old-cert delete failure independently; verify continue-on-error logic in both paths and that WebHosting import failure short-circuits the rebind.

**Integration:** Simulate a rebind failure and an old-cert delete failure; verify renewal continues and warnings are logged with the expected event IDs.

**Scripts:** Renewal script handles rebind and old-cert delete failures appropriately.
