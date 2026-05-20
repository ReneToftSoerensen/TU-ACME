# UC-3.1: Show supported DNS plugins in menu

**Category:** DNS plugins and credentials  
**Priority:** High

## Goal
Provide the user with an interactive list of the many DNS plugins that Posh-ACME supports.

## Actors
- System administrator (Admin)

## Preconditions
- Posh-ACME is installed with plugins available.

## Main flow
1. The user is in the middle of certificate ordering and needs to select a validation method.
2. The TUI loads the list of available plugins from Posh-ACME's plugin folder.
3. Plugins are presented in a scrollable, searchable list, e.g.:
   ```
   Select DNS plugin (use arrow keys, search with /):
   > Azure
     Cloudflare
     Route53
     GoDaddy
     Manual
     ...
   ```
4. The user navigates with the arrow keys and confirms the selection with Enter.

## Postconditions
- A DNS plugin has been selected and the process continues to UC-3.2.

## Alternative flows
- **2a:** Plugin folder not found -> error message, only "Manual" is offered as a fallback.
- **4a:** The user selects "Manual" -> the TUI guides them through manual DNS validation with a copyable TXT record.

## Technical notes
- The plugin list is retrieved via: `Get-PAPlugin` or by listing `.ps1` files in Posh-ACME's plugin folder.
- The search in the list filters instantly on keyboard input after `/`.
