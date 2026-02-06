# DIAGNOSTIC Sentinel Block (V1)

## Delimiters
- Opener regex: `^<<<DIAGNOSTIC:V1:(FIXED|MISMATCH)>>>$`
- Closer regex: `^<<<END_DIAGNOSTIC:(FIXED|MISMATCH)>>>$`

## Fields

### Mode: FIXED
- Body: a complete sentinel block that satisfies the parser contract for the target block type.
- No additional fields are required by this wrapper.

### Mode: MISMATCH
| Name | Type | Required | Constraints |
| --- | --- | --- | --- |
| COMPONENT | bare | yes | `PARSER`, `PROMPT`, or `BOTH` |
| EXPLANATION | quoted string | yes | single-line, max 500 chars |
| SUGGESTED_FIX | quoted string | yes | single-line, max 500 chars |

## Example
```
<<<DIAGNOSTIC:V1:MISMATCH>>>
COMPONENT=PARSER
EXPLANATION="Parser expects VERDICT:V1 but prompt specifies VERDICT:V2. Output cannot satisfy both."
SUGGESTED_FIX="Update parser regex to accept VERDICT:V2 or revert prompt to VERDICT:V1."
<<<END_DIAGNOSTIC:MISMATCH>>>
```

**Note:** Trailing whitespace on delimiter lines is tolerated by the parser.
