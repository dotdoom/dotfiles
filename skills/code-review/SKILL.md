---
name: code-review
description: >-
  Review code changes and pull requests. Use whenever asked to review a change,
  diff, branch, or PR.
---

# Code Review

Run these checks against the change under review before approving it.

## 1. Audit the change with the SDD `audit` skill

Determine which paths the change touches, then run the SDD plugin's `audit`
skill over them:

```bash
git diff --name-only origin/main...HEAD
```

Invoke the `audit` skill scoped to the changed paths and the subsystem they
belong to. It reports drift between the code and its ADRs and specs.

- Drift _introduced_ by the change means request changes: cite the violated
  ADR or spec requirement on the offending line.
- Pre-existing drift the change does not worsen is a note, not a blocker.

## 2. Confirm configuration is reversible

A NixOS configuration change is only safe while the machine can boot the
previous generation. Check the change does not break rollback, e.g.:

- no forward-only state migration a previous generation cannot read (database
  schema bumps, rewritten data directories, one-shot state migrations run at
  activation),
- nothing removes generations or garbage-collects the system profile,
- new secrets are not required to boot, so the previous generation still starts
  unattended.

If the change mutates state beyond what booting a previous generation can
undo, require an explicit rollback procedure in the change description.
