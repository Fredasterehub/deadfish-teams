# TRACK Sentinel Block (V1)

## Delimiters
- Opener regex: `^<<<TRACK:V1:NONCE=[0-9A-F]{6}>>>$`
- Closer regex: `^<<<END_TRACK:NONCE=[0-9A-F]{6}>>>$`

## Fields
| Name | Type | Required | Constraints |
| --- | --- | --- | --- |
| TRACK_ID | bare | yes | `^[A-Za-z0-9_-]+$`, max 64 chars |
| NAME | quoted string | yes | max 200 chars |
| PHASE | bare | yes | `^[A-Za-z0-9_-]+$`, max 64 chars |
| GOAL | quoted string | yes | max 500 chars |
| REQUIREMENTS | comma-separated bare list | yes | each item `^[A-Za-z0-9_-]+$`, 1–30 items |
| ESTIMATED_TASKS | integer | yes | positive, base-10 |
| PHASE_COMPLETE | boolean | no | `true` or `false` |
| PHASE_BLOCKED | boolean | no | `true` or `false` |
| REASONS | quoted string | conditional | required if `PHASE_BLOCKED=true`, max 500 chars |

## Example
```
<<<TRACK:V1:NONCE=4F2C9A>>>
TRACK_ID=core_bootstrap
NAME="Bootstrap unified parser"
PHASE=build
GOAL="Implement a shared parser and fixture set"
REQUIREMENTS=stdlib,fixtures,docs
ESTIMATED_TASKS=5
PHASE_COMPLETE=false
PHASE_BLOCKED=true
REASONS="Waiting on schema review"
<<<END_TRACK:NONCE=4F2C9A>>>
```

**Note:** Trailing whitespace on delimiter lines is tolerated by the parser.
