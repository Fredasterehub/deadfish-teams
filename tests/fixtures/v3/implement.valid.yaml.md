```deadfish:IMPLEMENT
task_id: auth-P1-T01
changed_files:
  - path: src/auth/jwt.ts
summary: Implemented JWT helper and tests.
verify:
  command: npm test -- jwt
  result: PASS
notes: No regressions observed.
```
