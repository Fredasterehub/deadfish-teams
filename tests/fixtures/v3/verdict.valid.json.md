```deadfish:VERDICT
{
  "scope": "TASK",
  "task_id": "auth-P1-T01",
  "verify_sh": "PASS",
  "criteria": [
    {"id": "AC-01", "status": "FAIL", "evidence": "Token expiry not handled"}
  ],
  "decision": "FAIL",
  "fix_forward": ["Add expiry handling"]
}
```
