# UC-4.02: Menu Search

## Narrative

As an **operator**, I want to **press `/` to search menu items by name**, so that **I can quickly jump to an item in a long menu**.

## Acceptance Criteria

- [ ] `/` key initiates search mode within any menu
- [ ] Search box appears and accepts keyboard input
- [ ] Matching items are highlighted; non-matching items are hidden or grayed out
- [ ] Up/down arrows navigate filtered results
- [ ] Enter selects the highlighted result
- [ ] Escape cancels search and returns to the full menu
- [ ] Search is case-insensitive

## Implementation Notes

- Implemented within `Show-Menu` function
- Search state managed by the menu loop
- Filtered display uses the same `DisabledIndices` or hiding mechanism
- Search buffer is a simple string accumulation per keystroke

## Test Coverage

**Unit:** Mock console input and filtering logic; verify search state changes.

**Integration:** Run interactive menu; manually test search with `/` key.

**Scripts:** N/A
