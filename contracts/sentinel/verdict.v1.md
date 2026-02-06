# VERDICT Sentinel Block (V1)

## Delimiters
- Opener regex: `^<<<VERDICT:V1:<CRITERION_ID>:NONCE=[0-9A-F]{6}>>>$`
- Closer regex: `^<<<END_VERDICT:<CRITERION_ID>:NONCE=[0-9A-F]{6}>>>$`

`<CRITERION_ID>` is provided via the CLI (`--criterion`) and must match exactly.

## Fields
| Name | Type | Required | Constraints |
| --- | --- | --- | --- |
| ANSWER | enum | yes | `YES` or `NO` |
| REASON | quoted string | yes | single line, max 500 chars |

## Example
```
<<<VERDICT:V1:AC1:NONCE=4F2C9A>>>
ANSWER=YES
REASON="All acceptance criteria are satisfied"
<<<END_VERDICT:AC1:NONCE=4F2C9A>>>
```

**Note:** Trailing whitespace on delimiter lines is tolerated by the parser.
