# UC-4.2: Sorting and filtering of the certificate list

**Category:** Dashboard  
**Priority:** Medium

## Goal
Make it easy to find specific certificates on machines with many domains.

## Actors
- System administrator (Admin)
- Monitor/Technician (ReadOnly)

## Preconditions
- The dashboard with the certificate list is displayed (UC-4.1).
- At least one certificate exists.

## Main flow
1. The user is in the dashboard table (UC-4.1).
2. **Search:** The user presses `/` to activate the search field.
   - An input line appears at the bottom: `Search: _`
   - The table is filtered instantly on every keystroke.
   - Press ESC to clear the search and return to the full list.
3. **Sorting:** The user presses `S` to cycle through the sorting options:
   - Sort by expiry date (ascending) <- default
   - Sort by expiry date (descending)
   - Sort alphabetically (A-Z)
4. The active sorting method is shown in the table header.

## Postconditions
- The table shows the filtered and/or sorted list.

## Alternative flows
- **2a:** No search results -> message: `No certificates match the search.`

## Technical notes
- Filtering is done on the `Domain` column (case-insensitive).
- Sorting is implemented with PowerShell `Sort-Object`.
