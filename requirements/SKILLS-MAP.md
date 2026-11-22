# QuakeStrikePH Required Skills Map

IT 123 Option 1C, Section 5.4 and Table 9 of the Final Project Guide v01.
Line numbers were checked on 23 November 2026.

| Skill | Module | Where it appears in our work |
| --- | --- | --- |
| Variables and correct quoting | 04 | [quakestrikeph-config.sh](../quakestrikeph-config.sh), lines **59 and 60**. `read_setting` stores the supplied path and key in local variables and quotes both when reading the file. |
| Command chaining to act on success or failure | 04 | [quakestrikeph-accounts.sh](../quakestrikeph-accounts.sh), line **149**. The script changes ownership before applying mode `600` and reports failure if either command fails. |
| Executable script with an interpreter line written in a command-line editor | 13 | [tests/check-scripts.sh](../tests/check-scripts.sh), line **1** and lines **12, 13, and 14**. The script begins with `#!/bin/bash`. See [Terminal editor and executable check](#terminal-editor-and-executable-check) for the `vi` edit and `chmod +x` test. |
| Input through positional parameters or `read` | 13 | [quakestrikeph-rebuild.sh](../quakestrikeph-rebuild.sh), lines **20, 39, 41, and 48**. It uses `$#` to count arguments, `$1` to identify the option, and `$2` to read its value. |
| A conditional that tests a condition or command status | 13 | [quakestrikeph-uninstall.sh](../quakestrikeph-uninstall.sh), lines **151, 153, and 154**. An `if` condition checks the confirmation flag and ends a preview before removal begins. |
| A loop that processes more than one item | 13 | [quakestrikeph-install.sh](../quakestrikeph-install.sh), lines **378 and 380**. A `for` loop checks each image required by the deployment. |
| A pipe with redirection and a regular expression | 11 | [tests/check-scripts.sh](../tests/check-scripts.sh), lines **13 and 14**. Help output passes through a pipe to `grep -E`. Output redirection saves the matching lines. See [Help output pipeline](#help-output-pipeline). |
| Archiving with compression and an integrity check | 12 | [TESTING-NOTES.md](../TESTING-NOTES.md#prepare-the-application-archive), **Prepare the application archive**, line **387**, shows gzip compression with `tar -czf`. [quakestrikeph-rebuild.sh](../quakestrikeph-rebuild.sh), line **100**, checks readability with `tar -tzf`. [prepare-fresh-test.sh](../rehearsal-wsl/prepare-fresh-test.sh), lines **84 and 85**, also verifies the archive checksum. |
| Correct ownership and permissions | 10 | [quakestrikeph-accounts.sh](../quakestrikeph-accounts.sh), line **149**. The installed environment file is set to owner and group `root:root` and mode `600`. |
| Users, groups, or privilege checks | 08, 09 | [quakestrikeph-accounts.sh](../quakestrikeph-accounts.sh), lines **49, 118, and 122**. It checks root privileges and creates the dedicated group and user when needed. |
| Resource check using `df`, `free`, or `top` | 15 | [quakestrikeph-rebuild.sh](../quakestrikeph-rebuild.sh), line **97**. It uses `df -h` to report free space for `/tmp`, `/srv`, and `/var/lib`. |

## Terminal editor and executable check

The verification script was edited with `vi` in ordinary Ubuntu. Its
interpreter line is `#!/bin/bash`. A temporary copy on the Linux file system
had mode `644`. Running `chmod +x tests/check-scripts.sh` changed it to
`755`. Running `./tests/check-scripts.sh` as a regular user passed syntax,
help, and argument checks.

## Help output pipeline

This excerpt from the verification script saves the lines it uses to check
the help message.

```bash
bash "$repository/$script" --help |
    grep -E '^Usage:|^[[:space:]]*Example|--help' > "$work/help"
```

The pipe sends Bash output to `grep`. The extended regular expression selects
the usage line, the example heading, and lines that mention the help flag.
The `>` operator writes the selected lines to the temporary help file.
The rebuild help check saved three lines. With `pipefail` at line **4**, a
synthetic command that printed matching help text and exited with status
`37` caused the check to exit with the same status.
