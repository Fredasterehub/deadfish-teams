# DOCSYNC Contract (v3)

## Fence type
- `deadfish:DOCSYNC`

## Required keys
- `action` (string)

## Optional keys
- `touched_docs` (list of strings; required when `action=UPDATE|FLUSH`)
- `summary` (string; required when `action=UPDATE|FLUSH`)
- `nonce` (string, regex: `^[0-9A-F]{6}$`)

## Validators
- `action` enum: `NOP`, `BUFFER`, `UPDATE`, `FLUSH`
