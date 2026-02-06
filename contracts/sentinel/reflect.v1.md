# REFLECT Sentinel Block (V1)

## Delimiters
- Opener regex: `^<<<REFLECT:V1:NONCE=[0-9A-F]{6}>>>$`
- Closer regex: `^<<<END_REFLECT:NONCE=[0-9A-F]{6}>>>$`

## Fields
| Name | Type | Required | Constraints |
| --- | --- | --- | --- |
| UPDATES | list section | yes | `- doc=<TECH_STACK|PATTERNS|PITFALLS|RISKS|PRODUCT|WORKFLOW|GLOSSARY> action=<append|replace_section|noop> section="..." content="..."` |
| SCRATCH | multi-line | yes | `SCRATCH=` then 2-space indented lines (YAML), non-empty |

## Example
```
<<<REFLECT:V1:NONCE=4F2C9A>>>
UPDATES:
- doc=WORKFLOW action=append section="Sentinels" content="Added unified parser"
SCRATCH=
  notes:
    - Keep parser stdlib-only
<<<END_REFLECT:NONCE=4F2C9A>>>
```

**Note:** Trailing whitespace on delimiter lines is tolerated by the parser.
