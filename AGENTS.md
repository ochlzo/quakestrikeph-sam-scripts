# Repository guide

## Scope

This repository contains IT 123 Option 1C administration scripts for QuakeStrikePH.
Read `README.md` before changing installation behavior or preparing a server test.
The installer uses the application's existing local Compose files and database setup commands.
When changing those commands, inspect the matching application source and its local runtime guide first.
The application source lives in a separate QuakeStrikePH repository.

## Work with the group

John Benedict is the lead developer. Chenie leads project management, Dan handles UX and QA, and Sean handles UI development.
Use simple explanations appropriate for junior developers and treat each team member's work with respect.
During coaching, give the requested hints and explain new syntax when it first appears.
When the user requests implementation, complete the requested code and explain its execution order.
State assumptions and distinguish verified results from planned behavior.

## Code style

- Follow the existing Bash style, descriptive names, and direct control flow.
- Keep changes small enough for the group to trace and explain.
- Use comments for reasons and behavior that the commands do not make clear.
- Keep script files in LF format.
- Preserve working `--help` output, clear failure messages, and meaningful exit statuses.
- Validate required inputs before installing packages or starting application services.
- Keep repeated runs safe for the application's existing records and volumes.
- Explain concrete failure modes before proposing complexity beyond the student project's needs.

## Course requirements

Read the faculty project guide before changing an option requirement or claiming course compliance.
In the shared coursework workspace, the guide is located at `../IT123_Final-Project_ProjectGuide.html`.
Standalone clones need the faculty-supplied copy. Treat Debian and WSL presentation approval as unconfirmed until the user supplies confirmation.

- Disclose AI help in script headers and credit adapted code above the relevant code.
- Explain changed decisions and state updates so the group can understand every line.
- Use test data and the group's authorized server for execution.
- Keep credentials in owner-readable configuration files outside Git.
- Keep application archives, exported images, database backups, and real user records outside this repository.

## Verification and handoff

For documentation or script authoring, run Bash syntax and help checks without invoking installation.
For requested server execution, use the group's disposable environment and the prepared inputs described in `README.md`.
After installer changes, check argument errors, failure propagation, and a repeated run when the available environment permits.
Report which checks used command substitutes and which reached actual Docker services or PostgreSQL.
Finish with changed files, the behavior each change produces, test results, and remaining verification gaps.
