# TRACK Contract (v3)

## Fence type
- `deadfish:TRACK`

## Required keys
- `track_id` (string)
- `track_name` (string)
- `status` (string)
- `requirements` (list of strings)

## Optional keys
- `spec_path` (string)
- `plan_path` (string)
- `nonce` (string, regex: `^[0-9A-F]{6}$`)

## Validators
- `status` enum: `selected`, `planning`, `executing`, `complete`, `blocked`
