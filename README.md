# QuakeStrikePH SAM Scripts (Option 1C)

Administration scripts for the **IT 123 Final Project — Option 1C: Provision and Rebuild**.

These six Bash scripts install, configure, restore, remove, and rebuild the local **QuakeStrikePH** web application (Bulletin, Backend, PostgreSQL, and Redis) offline on **Ubuntu 24.04 LTS** or **Debian 13** with `systemd`.

---

## Repository contents

| Path | Purpose |
| --- | --- |
| `quakestrikeph-accounts.sh` | Creates/reuses the locked `quakestrikeph` service user/group (`10001:10001`) and applies least-privilege permissions. |
| `quakestrikeph-config.sh` | Generates or reuses the private root-only `.env` file (`mode 600`) with random OpenSSL passwords. |
| `quakestrikeph-install.sh` | Installs Docker from cached APT packages, loads `images.tar`, deploys files, runs migrations, and verifies HTTP responses. |
| `quakestrikeph-restore.sh` | Verifies and restores the compressed `.sql.gz` earthquake/forecast backup into PostgreSQL (safe to run twice). |
| `quakestrikeph-uninstall.sh` | Previews removal by default; `--confirm` deletes only the `quakestrikeph-sam` deployment, volumes, and service account. |
| `quakestrikeph-rebuild.sh` | Checks disk space (`df -h`) and archive integrity, runs all steps in order, and verifies the running website. |
| `man/quakestrikeph-toolkit.8` | Section-8 manual page covering all six scripts (`man ./man/quakestrikeph-toolkit.8`). |
| `tools/prepare-demo-artifacts.sh` | Local preparation helper (not one of the 6 submitted scripts) to export the two demo prerequisites. |

---

## Before the offline demo (two prerequisites + APT cache)

### 1. Pre-download Docker packages on the blank server (while online)
Run this once on the clean server before disconnecting from the internet:

```bash
sudo apt-get update

# Ubuntu 24.04 LTS:
sudo apt-get install --download-only docker.io docker-compose-v2

# Debian 13:
sudo apt-get install --download-only docker.io docker-cli docker-compose
```

Do **not** install Docker yet — `--download-only` leaves the `.deb` files in `/var/cache/apt/archives/` so `quakestrikeph-install.sh` installs them offline during the demo.

### 2. Export the two demo files (on your dev machine)
Use `tools/prepare-demo-artifacts.sh` against your local QuakeStrikePH checkout and test/staging database:

```bash
bash tools/prepare-demo-artifacts.sh \
    --app-repo /path/to/quakestrikeph \
    --output-dir ./demo-artifacts \
    --compose-project quakestrikeph-sam
```

*(You can pass `--db-url "postgresql://..."` instead of `--compose-project` if dumping from a database URL.)*

This produces two files to copy onto the blank server (for example into `/root/`):
1. `quakestrikeph-app.tar.gz` — tracked app files, `model-artifacts/`, and `images.tar`.
2. `quakestrikeph-db-backup.sql.gz` — compressed PostgreSQL data dump containing **only public/test earthquake, model, and forecast data** (user, account, alert, and session tables are excluded).

Keep credentials (`.env`), archives, and backups outside this Git repository.

---

## Running the toolkit

### Full rebuild on a blank server (recommended for live demo)

```bash
sudo bash quakestrikeph-rebuild.sh \
    --archive /root/quakestrikeph-app.tar.gz \
    --backup /root/quakestrikeph-db-backup.sql.gz
```

When it finishes, open **`http://127.0.0.1:4321`** to verify the website and restored earthquake forecasts.

### Running each script individually (same order)

```bash
sudo bash quakestrikeph-accounts.sh
sudo bash quakestrikeph-config.sh --output /root/demo.env
sudo bash quakestrikeph-install.sh \
    --archive /root/quakestrikeph-app.tar.gz \
    --config /root/demo.env
sudo bash quakestrikeph-accounts.sh
sudo bash quakestrikeph-restore.sh \
    --backup /root/quakestrikeph-db-backup.sql.gz
```

Every script is safe to run a second time without duplicating accounts, changing passwords, or wiping database records.

### Clean uninstall

Preview what will be removed (deletes nothing):
```bash
sudo bash quakestrikeph-uninstall.sh
```

Remove the deployment permanently:
```bash
sudo bash quakestrikeph-uninstall.sh --confirm
```

---

## Quick syntax and help checks (safe, no install)

```bash
for script in quakestrikeph-*.sh tools/prepare-demo-artifacts.sh
do
    bash -n "$script" && bash "$script" --help > /dev/null
done
```

Open the manual page (Linux/WSL with `man` installed):
```bash
man ./man/quakestrikeph-toolkit.8
```

---

## Academic integrity

AI assistance (Antigravity and ChatGPT) is disclosed in each script header and the manual page. Every group member must be able to explain every line of the six scripts during individual Q&A. Only sanitized/public earthquake data is used for the demo — never real user or client records.
