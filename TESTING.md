# Test the six QuakeStrikePH scripts

To demonstrate all six scripts, start with **Script 1 — Full rebuild**, then
run Scripts 2–6 one at a time. Run each command at the FreshTest Linux prompt
ending in `~/fresh-test-toolkit#`.

## Script 1. Full rebuild

This is the main rebuild command. It deploys the app from the prepared archive
and cached packages, then checks the saved forecast. It creates the private
configuration on a blank server and reuses it on repeat runs.

**▶ COPY AND RUN SCRIPT 1 — FreshTest Linux shell**

```bash

time bash quakestrikeph-rebuild.sh --archive /root/quakestrikeph-with-prediction.tar.gz --config /root/fresh-test.env

```

**Expected output** `Full rebuild successful: web responses passed and the demo forecast is saved.` The `real` line gives the elapsed time.

For the timed demo, follow the
[blank-server setup](TESTING-NOTES.md#manual-test-from-a-fresh-import) before
running Script 1. Running the same command on your existing FreshTest is a
repeat-run test. It briefly restarts the app and preserves existing credentials
and database volumes. Continue to Script 2 after the rebuild succeeds.

## Script 2. Accounts

**▶ COPY AND RUN SCRIPT 2**

```bash
bash quakestrikeph-accounts.sh
```

**Expected output** `Accounts setup successful: quakestrikeph (10001:10001).` The script reapplies file permissions.

## Script 3. Configuration

**▶ COPY AND RUN SCRIPT 3**

```bash
bash quakestrikeph-config.sh --output /root/fresh-test.env
```

**Expected output** `Configuration ready: existing file kept unchanged.`

## Script 4. Installation

**▶ COPY AND RUN SCRIPT 4**

```bash
bash quakestrikeph-install.sh --archive /root/quakestrikeph-with-prediction.tar.gz --config /root/fresh-test.env
```

**Expected output** `Installation successful. Application directory: /srv/quakestrikeph`.
The FreshTest app briefly restarts. Repeat Script 2 to apply final permissions before Script 5.

## Script 5. Seed the test data

**▶ COPY AND RUN SCRIPT 5**

```bash
bash quakestrikeph-seed.sh
```

**Expected output** `Seed successful: the demo forecast is saved.` Open the [FreshTest website](http://127.0.0.1:24321) and select **Sanitized prediction anchor**.

## Script 6. Preview uninstall

**▶ COPY AND RUN SCRIPT 6**

```bash
bash quakestrikeph-uninstall.sh
```

**Expected output** `Preview only: nothing removed.` This is the last script in the walkthrough.

[Testing notes](TESTING-NOTES.md) contain the offline setup details and past test results.
