```deadfish:ADR
{
  "decision_id": "ADR-0002",
  "status": "accepted",
  "context": "Task packets need deterministic scope checks against git diffs.",
  "options_considered": [
    "Keep manual review only",
    "Require Conductor reconciliation protocol"
  ],
  "decision": "Require Conductor reconciliation protocol and structured mismatch reporting.",
  "consequences": [
    "Boundary checks become repeatable",
    "Conductor output becomes auditable"
  ],
  "links": {
    "spec": "tracks/auth/spec.md",
    "plan": "tracks/auth/plan.md",
    "packet": "tracks/auth/TASKS/auth-P1-T02.md"
  },
  "supersedes": [
    "ADR-0001"
  ]
}
```
