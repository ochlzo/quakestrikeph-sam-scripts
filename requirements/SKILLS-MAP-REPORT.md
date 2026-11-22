# QuakeStrikePH Required Skills Map report

**Requirement 4** covers Section 5.4 and Table 9 on page 13 of the IT 123 Final
Project Guide v01. The [Required Skills Map](SKILLS-MAP.md) was verified on
23 November 2026. It lists all 11 skills with their module numbers and the
exact script lines or documentation sections that show them.

## Evidence for the two gaps

| Skill | Verified result |
| --- | --- |
| Terminal editor and executable script | Used `vi` in ordinary Ubuntu to edit the help check in [tests/check-scripts.sh](../tests/check-scripts.sh). On a temporary native Linux copy, `chmod +x` changed mode `644` to `755`. Direct execution through the Bash interpreter line passed all six scripts' syntax, help, and argument checks. |
| Pipe with redirection and a regular expression | The check now pipes help output into `grep -E` and redirects the matching lines to a temporary file. The rebuild help produced three matching lines. A synthetic help command that printed matching lines and returned status `37` caused the check to return `37` through `pipefail`. |

## Other checks

- Checked all 11 rows, module numbers, source line references, and document
  links against the saved files.
- Compressed and listed a synthetic archive using `tar`. A separate invalid
  archive failed the readability check as expected.
- Ran the documented `df` resource check in ordinary Ubuntu. The local
  Git Bash run also passed the script syntax, help, and argument checks.
- Compared SHA-256 hashes for the six course scripts before and after this
  work. All six matched.

The only code change was to the existing script check. The executable mode
was verified on a Linux copy. The upstream failure case used a synthetic
command. Verification stayed within local shell checks and did not reach
Docker, PostgreSQL, or the working demo.
