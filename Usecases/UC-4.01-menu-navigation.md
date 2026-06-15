# UC-4.01: Menu Navigation

## Narrative

As an **operator**, I want to **navigate menus using arrow keys and Enter**, so that **I can select and invoke menu items without using the mouse**.

## Acceptance Criteria

- [x] Up arrow moves selection to previous menu item
- [x] Down arrow moves selection to next menu item
- [x] Enter invokes the selected menu item
- [x] Selection wraps at top and bottom of menu
- [x] Current selection is visually highlighted (Cyan/DarkCyan)
- [x] Disabled items are skipped during navigation

## Implementation Notes

- Core function: `Show-Menu` (custom implementation, not a third-party TUI library)
- Uses Windows console host functions (ReadKey, WriteOutput)
- Disabled items tracked via `DisabledIndices` array
- Menu loop continues until a valid selection is made

## Test Coverage

**Unit:** Mock host console functions; verify navigation state machine.

**Integration:** Run interactive menu; manually verify keyboard input works as expected.

**Scripts:** N/A
