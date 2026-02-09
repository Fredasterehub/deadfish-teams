# IMPLEMENT Contract (v3)

## Fence type
- `deadfish:IMPLEMENT`

## Required keys
- `task_id` (string, regex: `^[a-z]+-P\d+-T\d{2}$`)
- `changed_files` (list of objects)
- `summary` (string)
- `verify` (object)

## Optional keys
- `notes` (string)
- `nonce` (string, regex: `^[0-9A-F]{6}$`)

## `changed_files[]` item schema
- Required: `path`
- Optional: none

## `verify` object schema
- Required: `command`, `result`
- Optional: none
- Validators:
  - `result` enum: `PASS`, `FAIL`
