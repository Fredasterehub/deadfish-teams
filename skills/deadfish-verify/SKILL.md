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
bash bin/verify.sh --project-dir <path> --task-file <task.md> --mode pre-commit
bash bin/verify.sh --project-dir <path> --task-file <task.md> --mode post-commit --base-commit <sha>
```
Env fallback (if flags omitted): `VERIFY_PROJECT_DIR`, `VERIFY_TASK_FILE`, `VERIFY_MODE`, `VERIFY_BASE_COMMIT`.
Modes:
- `pre-commit`: diff working tree vs `--base-commit` (or `HEAD`), skips git-clean check.
- `post-commit` (default): diff `--base-commit..HEAD`, enforces git-clean check.
Task `## FILES` canonical format:
```yaml
- path: src/auth/jwt.ts
  action: add
  rationale: new JWT module
```
Compat accepted: `path=src/foo.ts action=add`
Checks: tests, linter, diff budget (<=3x ESTIMATED_DIFF), scope/blocked files, secrets, git clean (post-commit only).
Output: structured JSON. Exit `0` when `pass=true`; exit non-zero when `pass=false`.

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
