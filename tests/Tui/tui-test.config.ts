// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
//
// tui-test configuration for the TU-ACME interactive terminal UI suite.
//
// Every test launches the same harness (launch.ps1) in a real pwsh pty. The
// harness imports the module and starts the interactive menu against a throwaway
// temp state directory. A wide terminal is used because the menu separators are
// 108 columns wide (Private/UI.ps1 Write-Sep) and would otherwise wrap.
//
// NOTE: PowerShell's Read-Host only receives pty keystrokes on Windows (conpty);
// on Linux/macOS the menu renders but cannot be driven. CI therefore runs this
// suite on a Windows runner.

import path from "node:path";
import { defineConfig, Shell } from "@microsoft/tui-test";

const launch = path.resolve(process.cwd(), "launch.ps1");

export default defineConfig({
  // Retry and trace make the suite resilient and debuggable on CI.
  retries: 2,
  trace: true,
  // The full-integration spec issues a real certificate, which can take a
  // couple of minutes (ACME order -> DNS-01 -> finalize). The issuance wait
  // alone allows up to 4 minutes, and there are several wizard steps before and
  // after it, so the ceiling is set to 10 minutes to leave ample headroom on
  // slower CI runners. Menu specs finish in seconds regardless of this ceiling.
  timeout: 10 * 60 * 1000,
  expect: { timeout: 10 * 1000 },
  use: {
    shell: Shell.Powershell,
    columns: 120,
    rows: 40,
    program: { file: "pwsh", args: ["-NoProfile", "-File", launch] },
  },
});
