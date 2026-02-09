# PLAN Contract (v3)

## Fence type
- `deadfish:PLAN`

## Required keys
- `track_id` (string)
- `base_commit` (string, regex: `[0-9a-f]{7,40}`)
- `tasks` (list of objects)

## Optional keys
- `nonce` (string, regex: `^[0-9A-F]{6}$`)

## `tasks[]` item schema
- Required: `id`, `title`, `depends_on`, `packet_path`
- Optional: none
- Notes:
  - `id` is task-local token like `T01`
  - `depends_on` is a list of task-local IDs
