# UC-9.02: IIS Binding Update

## Narrative

As an **automated system**, I want to **update IIS bindings with new certificate thumbprints**, so that **HTTPS bindings use the latest certificate after renewal**.

## Acceptance Criteria

- [ ] Rebind operation updates the binding's certificate thumbprint
- [ ] Binding is updated in IIS configuration
- [ ] IIS application pool is restarted (or binding is re-bound to activate)
- [ ] Event Log entry ID 1002 is written on success
- [ ] Rebind can be triggered manually or automatically after renewal
- [ ] Multiple bindings can be updated in a single operation
- [ ] Operation preserves all other binding settings (host header, port, etc.)

## Implementation Notes

- Rebind via `Set-WebBinding` or direct IIS configuration update
- Requires admin privileges
- Can happen automatically after renewal or on-demand from menu

## Test Coverage

**Unit:** Mock `Set-WebBinding` and IIS state; verify thumbprint update.

**Integration:** Update a binding; verify thumbprint changes in IIS.

**Scripts:** Renewal script calls rebind after import.
