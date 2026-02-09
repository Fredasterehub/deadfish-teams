```deadfish:TASK
task_id: auth-P1-T01
title: Add JWT module
goal: Implement signed token generation and verification.
acceptance_criteria:
  - id: AC-01
    type: DET
    text: JWT encode/decode tests pass
files:
  - path: src/auth/jwt.ts
    action: add
    rationale: Introduce JWT helper
commands:
  - npm test -- jwt
summary: Implemented JWT helper and tests.
estimated_diff: 42
```
