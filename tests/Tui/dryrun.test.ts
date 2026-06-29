// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
//
// Verifies the Dry-Run banner. Launching the harness with -DryRun makes
// Start-TUACME set $script:DryRun, and Show-MainMenu prints the Dry-Run notice.

import path from "node:path";
import { test, expect } from "@microsoft/tui-test";

const launch = path.resolve(process.cwd(), "launch.ps1");

test.use({
  program: { file: "pwsh", args: ["-NoProfile", "-File", launch, "-DryRun"] },
});

test("shows the Dry-Run notice when started with -DryRun", async ({ terminal }) => {
  await expect(terminal.getByText("Q: Quit")).toBeVisible();
  await expect(
    terminal.getByText("Dry-Run mode: no changes will be made", { strict: false })
  ).toBeVisible();
});
