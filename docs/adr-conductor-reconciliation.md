# ADR and Conductor Reconciliation

This project treats accepted architectural decisions as track-level constraints, then requires Conductor to reconcile those decisions against execution evidence.

## Decision capture

- Brainstormer produces ADR-ready content for accepted directions.
- Decision records are stored in `docs/adr/` (or referenced from `tracks/<track_id>/DECISIONS.md` before formalization).
- Use stable IDs (`ADR-0001`, `ADR-0002`, ...).

## Conductor reconciliation contract

Before returning `deadfish:CONDUCTOR`, Conductor must reconcile:

1. Plan graph vs packet reality:
   - every planned packet path exists
   - packet acceptance criteria still match plan/spec intent
2. Packet intent vs repo reality:
   - changed files align with packet scope
   - commit evidence supports claimed task completion
3. Reported progress vs decision constraints:
   - implementation does not violate accepted ADR decisions

When mismatches exist, include deterministic action lines in `recommended_changes`:

```text
MISMATCH:<id> SOURCE:<plan|packet|commit|adr> IMPACT:<low|med|high> ACTION:<next step>
```

## Practical guidance

- If ADR constraints and implementation diverge, prefer `ADAPT` or `REPLAN` over optimistic `CONTINUE`.
- If ADRs are missing for high-impact choices, request ADR formalization before scale-up.
- Keep reconciliation evidence file/commit based, not conversational.
