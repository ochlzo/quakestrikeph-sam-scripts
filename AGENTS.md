# Repository guide

## Scope

This repository contains the IT 123 Option 1C (Provision and Rebuild) administration scripts for QuakeStrikePH.
The application source lives in a separate QuakeStrikePH repository.
Read `README.md` before changing installation or restore behavior.

This toolkit uses two prepared offline inputs:
1. A compressed application archive (`quakestrikeph-app.tar.gz`) containing tracked source files, `model-artifacts/`, and `images.tar`.
2. A compressed PostgreSQL backup (`quakestrikeph-db-backup.sql.gz`) containing only public/test earthquake, model, and forecast data (never real user or account records).

Local preparation helpers live under `tools/` and are not part of the six submitted Option 1C scripts.

## Work with the group

- John Benedict is the lead developer (upper-junior).
- Chenie is the project lead and manager (junior).
- Dan handles UX and QA (junior).
- Sean handles UI development (super-junior).

Use simple, direct explanations and treat every member's work with respect.
Every member must be able to explain every line of all six scripts during individual Q&A.

## Code style

- Write scripts in basic, readable Bash (`if`/`then`/`fi`, `for`, `while`, clear variable names).
- Favor simplicity over heavy defensive edge-case guards. Do not add complex shell idioms (like `find -prune -o`, octal bitwise math, `env -i` wrappers, or `findmnt` loops) unless required for safe demo operation.
- Keep all script files in LF format and executable (`chmod +x`).
- Include a header comment block with purpose, authors, usage, AI assistance disclosure, and source credits.
- Preserve working `--help` output with options and at least one example.
- Check root privileges and required inputs before making system changes.
- Keep every script safe to run twice (idempotent) without duplicating accounts, overwriting credentials, or wiping existing database records.
- Print clear success and failure messages and return exit status `0` on success or non-zero on failure.

## Course requirements

Check the faculty project guide (`../IT123_Final-Project_ProjectGuide.html` in the shared coursework workspace) before changing an option requirement.

- Disclose AI assistance in script headers and credit adapted code above the relevant code.
- Use test or sanitized public earthquake data only. Never include real user accounts, passwords, or private keys in this repository or in demo backups.
- Keep credentials in a root-only (`600` or `400`) `.env` file outside Git and outside the application archive.
- Keep the section-8 manual page in `man/quakestrikeph-toolkit.8` aligned with all six scripts.

## Verification and handoff

- After editing scripts, run `bash -n` syntax checks and `--help` checks on every script.
- When running real deployment tests, use a disposable clean Linux server/WSL clone with cached APT packages and report what passed, what failed, and any remaining gaps.
