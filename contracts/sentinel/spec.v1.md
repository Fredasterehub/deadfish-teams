# SPEC Sentinel Block (V1)

## Delimiters
- Opener regex: `^<<<SPEC:V1:NONCE=[0-9A-F]{6}>>>$`
- Closer regex: `^<<<END_SPEC:NONCE=[0-9A-F]{6}>>>$`

## Fields
| Name | Type | Required | Constraints |
| --- | --- | --- | --- |
| TRACK_ID | bare | yes | `^[A-Za-z0-9_-]+$`, max 64 chars |
| TITLE | quoted string | yes | max 200 chars |
| SCOPE | multi-line | yes | `SCOPE=` then 2-space indented lines; non-empty; max 4000 chars |
| APPROACH | multi-line | yes | `APPROACH=` then 2-space indented lines; non-empty; max 4000 chars |
| CONSTRAINTS | multi-line | yes | `CONSTRAINTS=` then 2-space indented lines; non-empty; max 4000 chars |
| SUCCESS_CRITERIA | list section | yes | `- id=SC<n> text="..."` (quoted text), 1–30 items |
| DEPENDENCIES | list section | yes | `- "quoted dependency"`, 0–30 items |
| ESTIMATED_TASKS | integer | yes | positive, base-10 |

## Example
```
<<<SPEC:V1:NONCE=4F2C9A>>>
TRACK_ID=core_bootstrap
TITLE="Unified sentinel parser"
SCOPE=
  Build a single parser with shared validation logic.
  Keep stdlib-only and single-file.
APPROACH=
  Generalize the PLAN parser into a configurable core.
  Add per-block validators.
CONSTRAINTS=
  No external dependencies.
  Enforce 16KB payload cap.
SUCCESS_CRITERIA:
- id=SC1 text="All sentinel types parse with strict validation"
DEPENDENCIES:
- "No external libraries"
ESTIMATED_TASKS=7
<<<END_SPEC:NONCE=4F2C9A>>>
```

**Note:** Trailing whitespace on delimiter lines is tolerated by the parser.
