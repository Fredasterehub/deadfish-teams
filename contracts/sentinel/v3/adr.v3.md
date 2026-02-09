# ADR Contract (v3)

## Fence type
- `deadfish:ADR`

## Required keys
- `decision_id` (string, regex: `^ADR-\d{4,}$`)
- `status` (string)
- `context` (string)
- `options_considered` (list)
- `decision` (string)
- `consequences` (list)
- `links` (list of objects OR object/map)

## Optional keys
- `date` (string, regex: `^\d{4}-\d{2}-\d{2}$`)
- `authors` (list)
- `supersedes` (list of decision IDs)
- `superseded_by` (list of decision IDs)
- `nonce` (string, regex: `^[0-9A-F]{6}$`)

## Validators
- `status` enum: `proposed`, `accepted`, `superseded`

## `links[]` item schema (when links is a list)
- Required: `label`, `url`
- Optional: none
