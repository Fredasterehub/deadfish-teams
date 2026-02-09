```deadfish:TASK
{
  "task_id": "auth-P2-T02",
  "title": "Add refresh endpoint",
  "goal": "Expose refresh token endpoint.",
  "acceptance_criteria": [
    {"id": "AC-01", "type": "DET", "text": "Refresh route returns 200"}
  ],
  "files": [
    {"path": "src/auth/refresh.ts", "action": "add", "rationale": "New handler"}
  ],
  "commands": ["npm test -- refresh"],
  "summary": "Added refresh endpoint implementation.",
  "estimated_diff": 25
}
```
