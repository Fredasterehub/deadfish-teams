# VERDICT Contract (v3)

## Fence type
- `deadfish:VERDICT`

## Required keys
- `scope` (string)
- `task_id` (string, regex: `^[a-z]+-P\d+-T\d{2}$`)
- `verify_sh` (string)
- `criteria` (list of objects)
- `decision` (string)

## Optional keys
- `nonce` (string, regex: `^[0-9A-F]{6}$`)
- `fix_forward` (list of strings; required when `decision=FAIL`)

## Validators
- `scope` enum: `TASK`, `TRACK`
- `verify_sh` enum: `PASS`, `FAIL`
- `decision` enum: `PASS`, `FAIL`

## `criteria[]` item schema
- Required: `id`, `status`, `evidence`
- Optional: none
- Validators:
  - `id` regex: `^AC-\d{2,}$`
  - `status` enum: `PASS`, `FAIL`
