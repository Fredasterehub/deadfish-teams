# CONDUCTOR Contract (v3)

## Fence type
- `deadfish:CONDUCTOR`

## Required keys
- `decision` (string)
- `because` (list of strings)

## Optional keys
- `recommended_changes` (list of strings)
- `risks_if_ignored` (list of strings)
- `nonce` (string, regex: `^[0-9A-F]{6}$`)

## Validators
- `decision` enum: `CONTINUE`, `ADAPT`, `REPLAN`, `ESCALATE`
