---
name: deadfish-verify
description: Verification protocol, criteria rubric, verdict format.
---

# deadfish-verify — Verification Protocol

## Order of Operations
1. **Deterministic gate** (verify.sh) — always first
2. **LLM criteria fan-out** — only if DET passes
3. **Aggregate** (build-verdict.py)

## verify.sh
```bash
bash bin/verify.sh --project-dir <path> --task-file <task.md>
```
Checks: tests, linter, diff budget (≤3x ESTIMATED_DIFF), blocked files, secrets, git clean.
Output: structured JSON. Exit 0 always (result in JSON `pass` field).

## Criteria Rubric (for LLM-tagged ACs)
Three levels — ALL must pass:
- **EXISTS**: Artifact appears in the diff
- **SUBSTANTIVE**: Real code, not TODO/stub/placeholder
- **WIRED**: Connected into the system (import/export/route/config/DI/CLI)

## Bias
False negatives are acceptable. False positives are expensive. If uncertain: FAIL.

## Verdict Sentinel

    ```deadfish:VERDICT
    scope: TASK
    task_id: auth-P1-T02
    verify_sh: PASS
    criteria:
      - id: AC-01
        status: PASS
        evidence: "src/auth/jwt.ts exports generateToken, imported in src/auth/index.ts"
      - id: AC-03
        status: FAIL
        evidence: "no error handling for expired tokens"
    decision: FAIL
    fix_forward:
      - "Add try/catch in jwt.ts:generateToken for TokenExpiredError"
    ```

## Build Verdict Aggregation
```bash
echo "$verdicts_json" | python3 bin/build-verdict.py
```
Output: PASS (all YES) | FAIL (any NO) | NEEDS_HUMAN (parse error)

## Track-Level QA (P10)
6 categories: C0 Scope, C1 Docs, C2 Consistency, C3 Architecture, C4 Completeness, C5 Safety.
Never set C*=FAIL without ≥1 MAJOR+ finding (R2 rule).
