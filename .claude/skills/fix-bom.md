---
name: fix-bom
description: Use after creating or editing any .ps1/.psm1/.psd1 file (Write/Edit emit BOM-less UTF-8), or when CodeQuality BOM tests fail. Prepends the UTF-8 BOM to any PowerShell file missing it.
---

The Write/Edit tools emit UTF-8 without BOM, but `tests/Unit/CodeQuality.Tests.ps1` and the `.githooks/pre-commit` hook reject PowerShell files whose first three bytes are not `EF BB BF`. After touching PowerShell files, repair them:

```bash
for f in $(git ls-files -cmo --exclude-standard '*.ps1' '*.psm1' '*.psd1'); do
  head -c3 "$f" | od -An -tx1 | grep -q 'ef bb bf' || {
    printf '\xEF\xBB\xBF' | cat - "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    echo "BOM added: $f"
  }
done
```

Note `Edit` preserves an existing BOM, so only newly created files normally need repair. To check without modifying, use the `verify-utf8-bom` skill instead.
