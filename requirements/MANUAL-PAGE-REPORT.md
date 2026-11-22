# QuakeStrikePH Section 8 manual report

**Requirement 2** covers Section 5.2 of the IT 123 Final Project Guide v01 on
pages 11 and 12 and the template in Appendix C on page 20. The manual was
reviewed on 23 November 2026.

| Requirement | Result |
| --- | --- |
| One local Section 8 manual | [quakestrikeph-toolkit.8](man/quakestrikeph-toolkit.8) uses the project name and declares section 8. It opens directly with `man`. |
| Required sections | NAME, SYNOPSIS, DESCRIPTION, COMMANDS, EXAMPLES, FILES, EXIT STATUS, AUTHORS, and SEE ALSO appear in the rendered page. |
| Six script entries | Installation, Accounts, Configuration, Seed, Uninstall, and Full rebuild each have one COMMANDS entry. The synopsis and command entries match the supported options. All six accept `--help`. |
| Examples and operator reference | The manual shows the rebuild, individual setup, uninstall preview, script help, and how to open the manual. It documents configuration and archive paths, data volumes, logs, exit statuses, and related manuals. |
| Authors | The four full author names match the group proposal. The manual credits AI assistance and the faculty template. |

## Changes

- Matched the timed rebuild example to [TESTING.md](TESTING.md) and documented
  the FreshTest configuration path and Windows ports. Kept the Rehearsal ports
  and configuration path distinct.
- Listed the deployment archive and related guides under FILES. Moved the
  testing history reference out of the command examples.
- Clarified that deployment examples run from the toolkit directory and the
  `man` command shown runs from the repository root.
- Replaced author surnames with the full names from the group proposal.

## Verification

- Opened the page in Ubuntu with `man ./man/quakestrikeph-toolkit.8` from the
  repository root and `man ./quakestrikeph-toolkit.8` from the `man` directory.
  Both rendered the nine sections and six command entries.
- Rendered with Groff warnings enabled and received no diagnostics.
- Parsed all five example blocks with Bash. The rebuild command matched the
  FreshTest walkthrough and the uninstall example used preview mode.
- Ran the six scripts' syntax, help, and argument checks in local Git Bash.
  Verification stayed within rendering, parsing, and argument checks.
