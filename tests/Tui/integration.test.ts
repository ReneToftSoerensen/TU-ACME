// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
//
// Full-scale integration test: drive the N wizard end-to-end so the TUI issues
// a REAL certificate against the test ACME server (Pebble), using the IIS site
// with an HTTP host-header binding that CI provisions and the DNS test plugin
// (ChallTestSrv) configured by launch.ps1.
//
// This is the Windows-only counterpart of tests/Integration/*.Integration.Tests.ps1
// but exercised through the interactive UI rather than the helpers directly. It
// is opt-in: it only runs when CI has provisioned the ACME server + IIS host
// header (signalled by TUACME_TUI_INTEGRATION=1). Off that path it is skipped,
// so a plain `npx @microsoft/tui-test` run executes only the menu specs.

import { test, expect } from "@microsoft/tui-test";

const integrationEnabled =
  process.env.TUACME_TUI_INTEGRATION === "1" &&
  !!process.env.TUACME_ACME_DIRECTORY;

// Allow plenty of time for the ACME order -> DNS-01 -> finalize round trip.
const issueTimeout = 4 * 60 * 1000;

test.when(
  integrationEnabled,
  "issues a certificate end-to-end through the wizard",
  async ({ terminal }) => {
    // Main menu -> N: Create certificate.
    await expect(terminal.getByText("Q: Quit")).toBeVisible();
    terminal.submit("N");

    // Step 1: Select IIS Sites -> select all, then confirm.
    await expect(terminal.getByText("Step 1: Select IIS Sites")).toBeVisible();
    terminal.submit("s s");
    await expect(terminal.getByText("Step 1: Select IIS Sites")).toBeVisible();
    terminal.submit("c");

    // Step 2: Filter Host Headers -> confirm the (single host-header) selection.
    await expect(terminal.getByText("Step 2: Filter Host Headers")).toBeVisible();
    terminal.submit("c");

    // Step 3: Choose Common Name -> Enter accepts the default (first host),
    // then confirm the identifier list.
    await expect(terminal.getByText("Step 3: Choose Common Name")).toBeVisible();
    terminal.submit("");
    await expect(terminal.getByText("Confirm? (y/r/x)")).toBeVisible();
    terminal.submit("y");

    // Step 4: ACME options -> confirm and request (plugin comes from config).
    await expect(terminal.getByText("Step 4: ACME options")).toBeVisible();
    terminal.submit("c");

    // Step 5: Confirm & run.
    await expect(terminal.getByText("Step 5: Confirm & run")).toBeVisible();
    await expect(terminal.getByText("Proceed?")).toBeVisible();
    terminal.submit("y");

    // The real issuance happens here; wait for the success line.
    await expect(terminal.getByText("Certificate issued. Thumbprint:")).toBeVisible({
      timeout: issueTimeout,
    });

    // Step 6 offers to create an HTTPS binding for the HTTP-only host; decline
    // to keep the assertion focused on issuance, then continue past Wait-UI.
    await expect(terminal.getByText("Create a new HTTPS binding", { strict: false })).toBeVisible();
    terminal.submit("n");
    await expect(terminal.getByText("Press Enter to continue", { strict: false })).toBeVisible();
    terminal.submit("");

    // Back at the main menu -> quit cleanly.
    await expect(terminal.getByText("Q: Quit")).toBeVisible();
    terminal.submit("Q");
    await expect(terminal.getByText("Goodbye.")).toBeVisible();
  }
);
