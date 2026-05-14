# Claw Code 2.0 PR and Issue Resolution Gate

This gate was added to the Claw Code 2.0 Ultragoal after the explicit requirement:

> all PRs should be merged and all issues should be resolved if resolvable and correct.

## Scope

Before the Claw Code 2.0 Ultragoal can be marked complete:

1. Every open GitHub PR at the current final-gate snapshot must be triaged.
2. PRs that are correct, compatible with Claw Code 2.0 direction, and pass required verification must be merged.
3. PRs that are stale, incorrect, duplicative, unsafe, spam, or outside Claw Code scope must not be merged; each needs a recorded rationale.
4. Every open GitHub issue at the current final-gate snapshot must be triaged.
5. Issues that are resolvable and correct must be fixed or explicitly linked to a merged fix.
6. Issues that are spam, duplicates, incorrect, unactionable, externally blocked, or not Claw Code work must be closed or labeled/commented with rationale when repository policy allows.
7. The final completion audit must use a fresh GitHub snapshot, not only the planning snapshot.

## Current live snapshot

A live snapshot was captured locally during G002 execution:

- PR snapshot: `.omx/research/github-live/open-prs.json`
- Issue snapshot: `.omx/research/github-live/open-issues.json`
- Captured on: 2026-05-14 during the active Ultragoal run.
- Observed counts: 50 open PR records and 1000 open issue records from GitHub CLI list calls.

These local `.omx/research/github-live/*` files are evidence inputs, not final proof. The final gate must refresh them and compare deltas.

## Required final evidence

The final report must include:

- Fresh `gh pr list --state open` and `gh issue list --state open` snapshots.
- A PR ledger with one row per PR: merge / reject / defer, reason, verification, commit/merge reference.
- An issue ledger with one row per issue: fixed / duplicate / spam / invalid / deferred-with-rationale / externally-blocked, reason, and linked evidence.
- Verification that no correct, mergeable PR remains unmerged without rationale.
- Verification that no resolvable, correct issue remains open without a fix or rationale.

## Non-goals

This gate does not require merging unsafe, unverified, incompatible, spam, or incorrect contributions. It requires explicit evidence-backed triage and action for everything that is correct and resolvable.
