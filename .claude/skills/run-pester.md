---
name: run-pester
description: Use when the user asks to run tests ("run tests", "run pester"). Invokes the Pester 5 test suite with the project's shared configuration.
---

Run `Invoke-Pester ./tests -Configuration (& .\tests\pester.config.ps1)` from the repo root. Optionally filter with `-Tag Unit`, `-Tag Integration`, or `-Tag Scripts` to scope to a single tier; the `LiveExternal` tag is excluded by default in the config. The Unit tier must finish in under 10 seconds — treat a slower run as a regression.

If Pester 5.5+ is not installed and `Install-Module` fails with a 403 (remote containers block PSGallery), install from nuget.org instead:

```bash
v=5.7.1
curl -sL "https://api.nuget.org/v3-flatcontainer/pester/$v/pester.$v.nupkg" -o /tmp/pester.nupkg
mkdir -p /tmp/pester-x && unzip -qo /tmp/pester.nupkg -d /tmp/pester-x
dest=~/.local/share/powershell/Modules/Pester/$v
mkdir -p "$dest" && cp -r /tmp/pester-x/tools/* "$dest"/
```

