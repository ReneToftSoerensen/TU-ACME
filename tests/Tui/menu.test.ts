// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
//
// End-to-end tests that drive the TU-ACME interactive menu (Start-TUACME)
// through a real pwsh terminal. Assertions stay at the menu / navigation layer
// (rendering, valid/invalid keys, quitting) so nothing IIS- or Posh-ACME-bound
// is exercised; deeper logic stays covered by the Pester unit/integration suites.

import { test, expect } from "@microsoft/tui-test";

test("renders the banner and the main menu", async ({ terminal }) => {
  await expect(terminal.getByText("TU-ACME")).toBeVisible();
  await expect(
    terminal.getByText("A Text User Interface for Posh-ACME on Windows (PowerShell 7)")
  ).toBeVisible();

  // Every main-menu entry is present.
  await expect(terminal.getByText("N: Create certificate (full options)")).toBeVisible();
  await expect(terminal.getByText("M: Manage renewals", { strict: false })).toBeVisible();
  await expect(terminal.getByText("B: Browse IIS bindings")).toBeVisible();
  await expect(terminal.getByText("S: Manage ACME accounts")).toBeVisible();
  await expect(terminal.getByText("T: Manage scheduled renewal tasks")).toBeVisible();
  await expect(terminal.getByText("Q: Quit")).toBeVisible();
});

test("rejects an invalid menu key with a warning", async ({ terminal }) => {
  await expect(terminal.getByText("Q: Quit")).toBeVisible();

  // 'X' is not one of N, M, B, S, T, Q -> Read-MenuChoice warns and re-prompts.
  terminal.submit("X");

  await expect(
    terminal.getByText("Invalid choice. Valid: N, M, B, S, T, Q", { strict: false })
  ).toBeVisible();
  // The menu is shown again after the rejected key.
  await expect(terminal.getByText("Q: Quit")).toBeVisible();
});

test("quits cleanly on Q", async ({ terminal }) => {
  await expect(terminal.getByText("Q: Quit")).toBeVisible();

  terminal.submit("Q");

  await expect(terminal.getByText("Goodbye.")).toBeVisible();
});
