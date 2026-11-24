# QuakeStrikePH SAM Scripts (Option 1C)

Administration scripts for the **IT 123 Final Project — Option 1C: Provision and Rebuild**.

These six Bash scripts provision, configure, restore, remove, and rebuild the local **QuakeStrikePH** web application (Bulletin, Backend, PostgreSQL, and Redis) offline on **Ubuntu 24.04 LTS** or **Debian 13** with `systemd`.

---

## Repository contents

| Path | Purpose |
| --- | --- |
| `quakestrikeph-accounts.sh` | Creates/reuses the locked `quakestrikeph` service account (`10001:10001`) and applies least-privilege permissions. |
| `quakestrikeph-config.sh` | Generates or reuses the private root-only `.env` file (`mode 600`) with random OpenSSL passwords. |
| `quakestrikeph-install.sh` | Installs Docker from cached APT packages, loads `images.tar`, deploys files, starts PostgreSQL + Redis, and creates base DB roles. |
| `quakestrikeph-restore.sh` | Verifies and restores the compressed `.sql.gz` schema + earthquake/forecast backup into PostgreSQL, grants roles, and starts Backend + Bulletin. |
| `quakestrikeph-uninstall.sh` | Previews removal by default; `--confirm` deletes only the `quakestrikeph-sam` deployment, volumes, and service account. |
| `quakestrikeph-rebuild.sh` | Checks disk space (`df -h`) and archive integrity, runs all steps in order, and verifies the running website. |
| `man/quakestrikeph-toolkit.8` | Section-8 manual page covering all six scripts (`man ./man/quakestrikeph-toolkit.8`). |
| `tools/prepare-demo-artifacts.sh` | Local preparation helper (not one of the 6 submitted scripts) to export the two offline demo files. |

---

## Step 1: Set up a clean WSL 2 server

You need a **blank** Linux server with `systemd` enabled and Docker's `.deb` packages pre-downloaded in `/var/cache/apt/archives/` (**not** installed yet).

### Option A — Import the team's shared clean backup *(Fastest)*
Ask the team for the shared `QuakeStrikePH-SAM-preinstall.tar` snapshot (keep it outside Git), then run in **Windows PowerShell**:

```powershell
New-Item -ItemType Directory -Path "C:\WSL\QuakeStrikePH-CleanTest" -Force
wsl.exe --import QuakeStrikePH-CleanTest "C:\WSL\QuakeStrikePH-CleanTest" "C:\path\to\QuakeStrikePH-SAM-preinstall.tar" --version 2
```

### Option B — Build a fresh clean WSL 2 server from scratch *(Ubuntu 24.04 or Debian 13)*
1. Install a dedicated named WSL 2 distribution (**PowerShell**):
   ```powershell
   wsl.exe --install -d Ubuntu-24.04 --name QuakeStrikePH-CleanTest
   ```
   *(Finish creating the Linux user when prompted.)*

2. Enable `systemd` inside the new distribution:
   ```bash
   sudo tee /etc/wsl.conf <<'EOF'
   [boot]
   systemd=true
   EOF
   ```

3. Restart the distribution so `systemd` starts (**PowerShell**):
   ```powershell
   wsl.exe --terminate QuakeStrikePH-CleanTest
   ```

4. While online, pre-download Docker packages **without installing them**:
   ```bash
   sudo apt-get update

   # Ubuntu 24.04 LTS:
   sudo apt-get install --download-only docker.io docker-compose-v2

   # Debian 13:
   sudo apt-get install --download-only docker.io docker-cli docker-compose
   ```

5. Export a clean baseline snapshot before testing (**PowerShell**):
   ```powershell
   wsl.exe --terminate QuakeStrikePH-CleanTest
   New-Item -ItemType Directory -Path "C:\WSL-Backups" -Force
   wsl.exe --export QuakeStrikePH-CleanTest "C:\WSL-Backups\QuakeStrikePH-SAM-preinstall.tar"
   ```

To reset your test server back to blank at any time, run `wsl.exe --unregister QuakeStrikePH-CleanTest` and re-run the `wsl.exe --import` command from Option A.

---

## Step 2: Get or export the two offline demo files

The toolkit expects two prepared files (kept outside this Git repository):
1. **`quakestrikeph-app.tar.gz`** — tracked app files and `images.tar` (Postgres, Redis, Backend, Bulletin — no worker image or model artifacts needed).
2. **`quakestrikeph-db-backup.sql.gz`** — compressed PostgreSQL dump containing the **full schema plus public/test earthquake, model, and forecast data** (user, account, alert, audit, job dispatch, and session tables are created empty with 0 rows).

Teammates can use the shared copies of these two files, or regenerate them from a local QuakeStrikePH checkout with Docker running:

```bash
bash tools/prepare-demo-artifacts.sh \
    --app-repo /path/to/quakestrikeph \
    --output-dir ../backups \
    --compose-project quakestrikeph-sam
```

*(Pass `--db-url "postgresql://..."` instead of `--compose-project` if dumping from a database URL, or omit both to rebuild only `quakestrikeph-app.tar.gz`.)*

---

## Step 3: Copy the scripts and archives into the clean server

From **Windows PowerShell** inside this repository folder (works even when WSL has `[automount] enabled=false` and a non-root default user like `sam`):

```powershell
# 1. Create a staging folder in the clean WSL distro (replace user/distro names if different)
wsl.exe -d QuakeStrikePH-CleanTest -u sam -- mkdir -p /home/sam/staging/toolkit

# 2. Copy the 6 scripts and both archives from Windows
Copy-Item ".\quakestrikeph-*.sh" "\\wsl.localhost\QuakeStrikePH-CleanTest\home\sam\staging\toolkit\"
Copy-Item "..\backups\quakestrikeph-app.tar.gz" "\\wsl.localhost\QuakeStrikePH-CleanTest\home\sam\staging\"
Copy-Item "..\backups\quakestrikeph-db-backup.sql.gz" "\\wsl.localhost\QuakeStrikePH-CleanTest\home\sam\staging\"

# 3. Move everything into /root and make the scripts executable
wsl.exe -d QuakeStrikePH-CleanTest -u root -- bash -c "mkdir -p /root/toolkit && mv /home/sam/staging/toolkit/*.sh /root/toolkit/ && mv /home/sam/staging/quakestrikeph-*.gz /root/ && rmdir /home/sam/staging/toolkit /home/sam/staging && chown -R root:root /root/toolkit /root/quakestrikeph-*.gz && chmod +x /root/toolkit/*.sh"

# 4. Verify all 6 scripts and both archives are in place
wsl.exe -d QuakeStrikePH-CleanTest -u root -- bash -c "ls -lh /root/quakestrikeph-*.gz /root/toolkit/"
```

---

## Step 4: Run the toolkit

Open a root shell inside your clean server (**PowerShell**):

```powershell
wsl.exe -d QuakeStrikePH-CleanTest -u root
```

### Full rebuild on a blank server *(live demo command)*
```bash
bash /root/toolkit/quakestrikeph-rebuild.sh \
    --archive /root/quakestrikeph-app.tar.gz \
    --backup /root/quakestrikeph-db-backup.sql.gz
```
*(Prefix with `time` during practice to measure elapsed time.)*

When it finishes with exit status `0`, open **`http://127.0.0.1:4321`** in your Windows browser to verify the website and restored earthquake forecasts.

### Running each script individually *(and testing repeat-safety)*
Every script is safe to run a second time without duplicating accounts, changing passwords, or wiping database records:

```bash
bash /root/toolkit/quakestrikeph-accounts.sh
bash /root/toolkit/quakestrikeph-config.sh --output /root/demo.env
bash /root/toolkit/quakestrikeph-install.sh \
    --archive /root/quakestrikeph-app.tar.gz \
    --config /root/demo.env
bash /root/toolkit/quakestrikeph-accounts.sh
bash /root/toolkit/quakestrikeph-restore.sh \
    --backup /root/quakestrikeph-db-backup.sql.gz
```

### Clean uninstall
Preview what will be removed (safe — deletes nothing):
```bash
bash /root/toolkit/quakestrikeph-uninstall.sh
```

Remove the deployment permanently (keeps Docker, cached images, backups, and `/root/demo.env`):
```bash
bash /root/toolkit/quakestrikeph-uninstall.sh --confirm
```

---

## Quick syntax, help, and manual checks

Run safely without installing anything:

```bash
for script in quakestrikeph-*.sh tools/prepare-demo-artifacts.sh
do
    bash -n "$script" && bash "$script" --help > /dev/null
done
```

Open the section-8 manual page (on Linux/WSL with `man` installed):
```bash
man ./man/quakestrikeph-toolkit.8
```

---

## Academic integrity and safe practice

- AI assistance (Antigravity and ChatGPT) is disclosed in each script header and in the manual page.
- Every group member must be able to explain every line of all six scripts during individual Q&A.
- Only public/sanitized earthquake and forecast data is used for the demo — never real user accounts, passwords, or private keys.
- Keep `.env` files, archives, backups, and WSL `.tar` snapshots outside Git.
