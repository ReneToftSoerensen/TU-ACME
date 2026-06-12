# UC-4.03: Menu Format & Colors

## Narrative

As a **code maintainer**, I want to **enforce consistent TUI styling** (79-char titles, Cyan/DarkCyan colors), so that **all menus look and feel uniform**.

## Acceptance Criteria

- [x] All menu titles are ≤79 characters (enforced in code review)
- [x] Menu output uses only Cyan and DarkCyan (no Red, Green, Yellow, Blue, Magenta)
- [x] Menu chrome (borders, selection highlight) uses DarkCyan
- [x] Menu text uses Cyan
- [x] Status messages use Cyan for info, DarkCyan for prompts
- [x] Validation errors use Cyan (not Red, for readability in terminal)

## Implementation Notes

- `Show-Menu` hardcodes `ForegroundColor = [ConsoleColor]::Cyan` and `BackgroundColor = [ConsoleColor]::DarkCyan`
- Title parameter validation rejects strings > 79 chars
- No RGB/ANSI 256-color sequences; stick to base 16 colors for maximum compatibility

## Test Coverage

**Unit:** Verify title length and color constants in code.

**Integration:** Visual inspection of rendered menus.

**Scripts:** N/A
