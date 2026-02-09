# INTEGRATE Contract (v3)

## Fence type
- `deadfish:INTEGRATE`

## Required keys
- `why_called` (string)
- `changes` (list of strings)
- `verify_sh` (string)

## Optional keys
- `nonce` (string, regex: `^[0-9A-F]{6}$`)

## Validators
- `verify_sh` enum: `PASS`, `FAIL`
