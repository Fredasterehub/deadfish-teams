# QA_REVIEW Sentinel Block (V1)

## Delimiters
- Opener regex: `^<<<QA_REVIEW:V1:NONCE=[0-9A-F]{6}>>>$`
- Closer regex: `^<<<END_QA_REVIEW:NONCE=[0-9A-F]{6}>>>$`

## Fields
| Name | Type | Required | Constraints |
| --- | --- | --- | --- |
| VERDICT | enum | yes | `PASS` or `FAIL` |
| RISK | enum | yes | `LOW`, `MEDIUM`, or `HIGH` |
| C0..C5 | enum | yes | each `PASS` or `FAIL` |
| FINDINGS_COUNT | integer | yes | non-negative |
| FINDINGS | list section | yes | `- severity=<CRITICAL|MAJOR|MINOR> category=<C0..C5> file="<path>" issue="..."` |
| REMEDIATION_COUNT | integer | yes | non-negative |
| REMEDIATION | list section | yes | `- file="<path>" action="..."` |
| NOTES | quoted string | yes | single line, max 500 chars |

## Example
```
<<<QA_REVIEW:V1:NONCE=4F2C9A>>>
VERDICT=PASS
RISK=LOW
C0=PASS
C1=PASS
C2=PASS
C3=PASS
C4=PASS
C5=PASS
FINDINGS_COUNT=1
FINDINGS:
- severity=MINOR category=C2 file="src/parser.py" issue="Improve error wording"
REMEDIATION_COUNT=1
REMEDIATION:
- file="src/parser.py" action="Adjust error messages"
NOTES="All checks completed"
<<<END_QA_REVIEW:NONCE=4F2C9A>>>
```

**Note:** Trailing whitespace on delimiter lines is tolerated by the parser.
