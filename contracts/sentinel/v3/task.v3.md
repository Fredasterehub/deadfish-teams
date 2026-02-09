# TASK Contract (v3)

## Fence type
- `deadfish:TASK`

## Required keys
- `task_id` (string, regex: `^[a-z]+-P\d+-T\d{2}$`)
- `title` (string)
- `goal` (string)
- `acceptance_criteria` (list of objects)
- `files` (list of objects; canonical FILES format)
- `commands` (list of strings)
- `summary` (string)
- `estimated_diff` (integer)

## Optional keys
- `risks` (list of strings)
- `rollback` (string)

## `acceptance_criteria[]` item schema
- Required: `id`, `type`, `text`
- Optional: none
- Validators:
  - `id` regex: `^AC-\d{2,}$`
  - `type` enum: `DET`, `LLM`

## `files[]` item schema
- Required: `path`, `action`, `rationale`
- Optional: none
- Validators:
  - `action` enum: `add`, `modify`, `delete`
