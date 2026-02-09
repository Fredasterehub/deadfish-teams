# PLAN Sentinel Block (V1)

## Delimiters
- Opener regex: `^<<<PLAN:V1:NONCE=[0-9A-F]{6}>>>$`
- Closer regex: `^<<<END_PLAN:NONCE=[0-9A-F]{6}>>>$`

## Fields
| Name | Type | Required | Constraints |
| --- | --- | --- | --- |
| TASK_ID | bare | yes | max 64 chars |
| TITLE | quoted string | yes | max 200 chars |
| SUMMARY | multi-line | yes | `SUMMARY=` then 2-space indented lines; non-empty; max 4000 chars |
| FILES | list section | yes | `- path=<bare> action=<add|modify|delete> rationale="..."`, 1–50 items |
| ACCEPTANCE | list section | yes | `- id=AC<n> text="..."`, 1–30 items |
| ESTIMATED_DIFF | integer | yes | positive, base-10, max 10 chars |
| NOTES | multi-line | no | `NOTES=` then 2-space indented lines; max 4000 chars |

## Example
```
<<<PLAN:V1:NONCE=4F2C9A>>>
TASK_ID=parser_unify
TITLE="Unify sentinel parsers"
SUMMARY=
  Implement a shared parsing core and per-block validators.
FILES:
- path=.deadf/bin/parse-blocks.py action=add rationale="Single unified parser"
ACCEPTANCE:
- id=AC1 text="parse-blocks.py plan emits JSON on valid input"
ESTIMATED_DIFF=180
NOTES=
  Keep behavior identical to legacy PLAN parsing.
<<<END_PLAN:NONCE=4F2C9A>>>
```

**Note:** Trailing whitespace on delimiter lines is tolerated by the parser.
