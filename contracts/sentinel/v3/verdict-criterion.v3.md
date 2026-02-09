# VERDICT_CRITERION Contract (v3)

## Fence type
- `deadfish:VERDICT_CRITERION`

## Required keys
- `task_id` (string, regex: `^[a-z]+-P\d+-T\d{2}$`)
- `criterion_id` (string, regex: `^AC-\d{2,}$`)
- `verify_sh` (string)
- `status` (string)
- `evidence` (string)

## Optional keys
- `nonce` (string, regex: `^[0-9A-F]{6}$`)
- `fix_forward` (list of strings; required when `status=FAIL`)

## Validators
- `verify_sh` enum: `PASS`, `FAIL`
- `status` enum: `PASS`, `FAIL`
