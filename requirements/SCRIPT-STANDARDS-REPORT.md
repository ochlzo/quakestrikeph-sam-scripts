# QuakeStrikePH script standards report

**Requirement 1** covers Section 5.1 of the IT 123 Final Project Guide v01
on page 11. This report records the 23 November 2026 review of the six
Option 1C Bash scripts.

| Standard | Evidence |
| --- | --- |
| Bash and script names | All six scripts use `#!/bin/bash`, have LF line endings, and follow the `quakestrikeph-task.sh` naming pattern. |
| Required headers | Each script states its purpose, lists its authors, and gives a usage command. The headers also disclose AI assistance. |
| Help output | Each `--help` command returned status `0` and displayed its options and a usage example. The uninstall example opens a preview. |
| Failure messages and exit status | All six scripts returned status `1` for an unknown option. All 11 missing-value cases returned status `1` and named the option requiring a value. |
| Prerequisite checks | All six scripts refused to run without root privileges in the local check. Source review confirmed tool checks and input checks before the relevant changes. |
| Private credentials | Source review found that configuration generates credentials for a new setup and reuses matching existing settings. The configuration script checks that input files are root-owned with mode `600` or `400`. The installer applies mode `600` to the deployed environment file. |

## Changes

- Added `--help` to the usage lines in [Accounts](quakestrikeph-accounts.sh),
  [Configuration](quakestrikeph-config.sh), [Seed](quakestrikeph-seed.sh),
  and [Uninstall](quakestrikeph-uninstall.sh). The Installer and Full rebuild
  help output already listed it.
- Updated [the script checks](tests/check-scripts.sh) to fail if an option
  listing omits `--help`.

## Verification

Bash syntax, help, option listings, error messages, missing values, and
non-root rejection passed in local Git Bash. The script test suite ran its
non-root checks. Its Linux systemd checks, including simulated package and
service operations, require the disposable Linux test environment.

The credential finding above comes from source review. This pass used the
repository scripts and local checks only. Live Docker and PostgreSQL results
remain recorded in the [testing history](TESTING-NOTES.md).
