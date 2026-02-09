# SPEC Contract (v3)

## Fence type
- `deadfish:SPEC`

## Required keys
- `track_id` (string)
- `goal` (string)
- `non_goals` (list of strings)
- `acceptance_criteria` (list of objects)

## Optional keys
- `constraints` (list of strings)
- `edge_cases` (list of strings)
- `out_of_scope` (list of strings)

## `acceptance_criteria[]` item schema
- Required: `id`, `type`, `text`
- Optional: none
- Validators:
  - `id` regex: `^AC-\d{2,}$`
  - `type` enum: `DET`, `LLM`
