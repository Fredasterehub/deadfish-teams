```deadfish:ADR
decision_id: ADR-0001
status: proposed
context: Drift between task packets and commit history is causing repeated replans.
options_considered:
  - Keep decisions in ad hoc chat messages.
  - Record decisions as sentinels and maintain a canonical ledger.
decision: Adopt ADR sentinels and a decisions ledger per track.
consequences:
  - Decision provenance becomes explicit and searchable.
  - Teams must maintain one extra artifact per architectural choice.
links:
  - label: spec
    url: tracks/auth/spec.md
  - label: plan
    url: tracks/auth/plan.md
date: "2026-02-09"
authors:
  - Platform Team
```
