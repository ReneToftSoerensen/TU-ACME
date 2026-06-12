---
name: review-fixes
description: Use when addressing PR review comments (Copilot or human) on this repo. Fetches unresolved threads, fixes with regression tests, pushes, and resolves the threads.
---

Work the review feedback loop:

1. **Fetch unresolved threads**: `pull_request_read` with method `get_review_comments`; skip threads already resolved or outdated.
2. **Triage each thread**: if the suggestion is wrong or can't be done, reply on the thread explaining why instead of changing code. If ambiguous, ask the user before acting.
3. **Fix with a regression test** — every behavioral fix gets a Pester test that would have caught the issue (project policy; see the `implement-uc` skill for test conventions). Pure-style fixes don't need one.
4. **Gates before pushing**: run `fix-bom`, then `run-pester` — the suite must be green.
5. **One commit for the round**, message style: `Address review: <comma-separated summary of fixes>`. Push to the PR branch.
6. **Resolve the threads** you addressed (`resolve_review_thread`) and confirm CI goes green on the new commit.
