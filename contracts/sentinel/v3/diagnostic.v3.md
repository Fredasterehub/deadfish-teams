# deadfish:DIAGNOSTIC — v3 Contract

Emitted by repair/diagnostic agents when format-repair retries fail.

## Schema

```yaml
outcome: FIXED|MISMATCH
# When FIXED:
corrected_block: |
  <corrected sentinel block content>
# When MISMATCH:
component: PARSER|PROMPT|BOTH
explanation: <what's wrong>
suggested_fix: <specific change needed>
nonce: <optional 6-char uppercase hex>
```

## Fields

| Field | Required | Values | Notes |
|-------|----------|--------|-------|
| outcome | yes | FIXED, MISMATCH | Determines which optional fields apply |
| corrected_block | when FIXED | multiline string | Must pass parser as-is |
| component | when MISMATCH | PARSER, PROMPT, BOTH | Where the problem lives |
| explanation | when MISMATCH | string (max 500 chars) | Single-line |
| suggested_fix | when MISMATCH | string (max 500 chars) | Single-line |
| nonce | no | 6-char uppercase hex | Optional traceability |
