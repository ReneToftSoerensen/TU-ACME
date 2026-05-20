# UC-1.4: Quick switch to the Staging/Test environment

**Category:** Account management  
**Priority:** High

## Goal
Make it easy to switch to the Let's Encrypt Staging environment during testing in order to avoid rate limits.

## Actors
- System administrator (Admin)

## Preconditions
- The TUI is started and shows a status bar at the bottom.

## Main flow
1. At the bottom of the TUI, the active account and server are shown (e.g. `Active: admin@example.com | Let's Encrypt Production`).
2. The user presses the hotkey **F3** (or selects the menu item "Switch to Staging").
3. The app checks whether a Let's Encrypt Staging account already exists.
4. If a staging account exists: the app switches immediately and the status bar is updated.
5. The status bar now shows: `Active: admin@example.com | Let's Encrypt STAGING`.

## Postconditions
- The active ACME server is Let's Encrypt Staging.

## Alternative flows
- **3a:** No staging account found -> the TUI guides the user to UC-1.2 with Let's Encrypt Staging preselected.

## Technical notes
- Let's Encrypt Staging URL: `https://acme-staging-v02.api.letsencrypt.org/directory`
- Staging certificates are not trusted by browsers, but they are suitable for testing.
