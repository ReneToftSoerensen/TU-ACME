# UC-9.03: IIS Rebind Failure Recovery

## Narrative

As an **automated system**, I want to **handle IIS rebind failures gracefully**, so that **renewal continues even if one binding cannot be updated**.

## Acceptance Criteria

- [ ] If a rebind fails for a single binding, it is logged but does not abort renewal
- [ ] Event Log entry ID 2001 (Warning) is written with binding details and error
- [ ] Renewal script continues to the next certificate/binding
- [ ] Error message is clear (e.g., "binding is in use" or "access denied")
- [ ] Operator is notified of the failed binding (via Event Log and dashboard)
- [ ] Failed bindings can be manually retried from the menu

## Implementation Notes

- Rebind is wrapped in try/catch at the operation level
- Errors are logged but do not propagate up the renewal chain
- Manual retry option available in certificate dashboard

## Test Coverage

**Unit:** Mock rebind failure; verify continue-on-error logic.

**Integration:** Simulate a rebind failure; verify renewal continues and warning logged.

**Scripts:** Renewal script handles rebind failures appropriately.
