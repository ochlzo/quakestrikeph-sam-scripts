# QuakeStrikePH runbook report

**Requirement 3** covers Section 5.3 of the IT 123 Final Project Guide v01
on page 12. The [administrator runbook](RUNBOOK.md) was prepared on
23 November 2026 for the group's QuakeStrikePH FreshTest environment.

| Required content | Where the runbook covers it |
| --- | --- |
| Application and server requirements | Introduces the earthquake bulletin and saved forecasts, Ubuntu 24.04 on WSL 2, systemd, root access, and the offline deployment inputs. |
| Step-by-step installation | Links to the blank-server setup, gives the full rebuild command, and shows how to verify the services and saved forecast. |
| Routine tasks and schedules | Covers start-of-session health checks, weekly disk checks and backup exports, backups before changes, and a restore check before handoff. |
| Troubleshooting and recovery | Gives Docker log and health checks, a full FreshTest export with a SHA-256 checksum, and a restore under a new WSL name. The restored forecast is checked before any rebuild or seeding. |
| Files, logs, and backups | Locates the toolkit, app archive, cached packages, private configuration, database volumes, service logs, and separate backup drive. |

The backup procedure uses a full FreshTest export so the application,
database, private settings, and forecast evidence can be recovered together.
The restore steps use a new test distribution and account for its shared ports
with FreshTest.

## Verification

- All nine Bash and PowerShell command blocks passed syntax checks. The local
  links and rebuild command were checked against the existing guides.
- Substituted Docker and systemd commands verified five backup and restore
  guard cases, including rejection of the working demo and Docker live restore.
- A synthetic file and substituted WSL commands exercised export and import.
  Real SHA-256 checks rejected a modified archive. Existing restore folders
  and failed exports were also rejected.
- All six course scripts passed the local syntax, help, and argument checks.

The runbook and summary report were the only files added for this requirement.
Verification did not reach Docker or PostgreSQL. A live export and restore of
the populated FreshTest deployment still needs a separate test on the backup drive.
