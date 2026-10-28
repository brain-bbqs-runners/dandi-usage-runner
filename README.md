<p align="center">
  <img src="docs/branding/dandi-runner.svg" width="250" alt="DANDI usage runner logo"/>

  <h1 align="center">DANDI Usage (Runner)</h1>
</p>

GitHub Action-controlled CRON jobs that extract the DANDI S3 access logs and generate the access summaries on the self-hosted Typhon runner
(moved from [CodyCBakerPhD/self-hosted-crons](https://github.com/CodyCBakerPhD/self-hosted-crons)).
The install, the extraction commands and the upload run through
[CodyCBakerPhD/dandi-s3-logs-action](https://github.com/CodyCBakerPhD/dandi-s3-logs-action) `@v3`,
and the pre-run check through [CodyCBakerPhD/check-runner-action](https://github.com/CodyCBakerPhD/check-runner-action) `@v1`.

| Workflow | Schedule |
| --- | --- |
| Run DANDI log extraction (then a restic snapshot of the cache) | Daily, 00:00 UTC |
| Update log inventory (`s5cmd sync` of the S3 Inventory the extraction reads) | Sundays, 00:00 UTC |
| Install DANDI extraction packages (creates the environment on Python 3.14 if needed; `recreate` rebuilds it) | Manual dispatch only |
| Update DANDI summaries | Sundays, Wednesdays and Saturdays, 06:00 UTC |
| Update microscopy summaries (DANDI:000108) | Mondays, 06:00 UTC |
| Update unassociated DANDI summaries | 1st of each month, 03:00 UTC |
| Scan DANDI extraction cache for excluded IPs (`validate excluded`, which fails, and so emails, if the cache still holds their requests) | Manual dispatch only |
| Remove excluded IPs from DANDI extraction cache (restic snapshot, then `reset excluded`, then `validate excluded`, which must come back clean; the removal is permanent, so un-excluding an IP later needs a full re-extraction) | Manual dispatch only |

## Configuration

A self-hosted runner with the labels `typhon` and `dandi` must be registered to this repository.

The workflows work under `/mnt/s3-logs/dandi-s3-logs` on the runner's host, which holds `uv`, the environment (`env`),
`extraction_cache`, `inventory`, `flocks`, `snapshots`, `tmp` and the `access-summaries` clone. The path is written into
the workflows, so no repository variables are needed. The extraction and its restic snapshot use `tmp` as their
temporary directory in place of `/tmp`.

On a fresh runner, dispatching the install workflow downloads `uv` and creates the environment, and the first summaries
run clones [dandi/access-summaries](https://github.com/dandi/access-summaries) over SSH. The clone and its pushes use the
runner user's own git credentials, so that user needs an SSH key with push access to it.

Repository secrets:

- `S3_LOG_EXTRACTION_PASSWORD`
- `MAXMIND_ACCOUNT_ID` / `MAXMIND_LICENSE_KEY`
- `_GITHUB_API_KEY` (token able to list this repository's runners, for the pre-run check)
- `MAIL_USERNAME` / `MAIL_PASSWORD` (failure notifications)

Requester IPs to leave out are listed on the runner's host in the runner user's `~/.s3-log-extraction/.env`, a
standard dotenv file holding one comma-separated, unquoted line.

```text
# Drogon
S3_LOG_EXTRACTION_EXCLUDED_IPS=192.0.2.1,192.0.2.2
```

The extraction drops their requests, every summaries workflow leaves them out, and the scan workflow checks the cache
for any of their requests extracted before they were listed. If it finds some, the remove workflow deletes them from
the cache. This one file covers all of them, and no repository secret
is needed. Only exact addresses are accepted. An absent file or an empty value leaves no one
out. The Python CLI reads the file with `python-dotenv`. Other tools on the host can read the same file directly, for
example a shell with `set -a; . ~/.s3-log-extraction/.env; set +a`, or a workflow step with
`cat ~/.s3-log-extraction/.env >> "$GITHUB_ENV"`. A variable already set in the environment takes precedence over the
file.

The inventory sync and the restic snapshot use what the runner's host already has: its own AWS credentials for
`s3://dandiarchive-inventory`, and `snapshots/restic` with its password file under `/mnt/s3-logs/dandi-s3-logs`.
