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

Requester IPs to leave out are listed on the runner's host in the runner user's
`~/.s3-log-extraction/excluded_ips.txt`, one address per line, with `#` comments. This file is the only list of
excluded addresses. The extraction drops their requests and every summaries workflow leaves them out, so no repository
secret is needed.

```text
192.0.2.1  # Drogon
192.0.2.2  # Drogon
```

Only exact addresses are accepted. Networks in CIDR notation and patterns are refused with an error. An absent or
empty file leaves no one out.

Exclusion only works in one direction over time. Adding an address drops its requests from future extraction.
Removing an address from the file does not bring its requests back, since they were never extracted. To include an
address again, the extraction has to be rerun from scratch (`reset extraction`, then a full `extract`).

The inventory sync and the restic snapshot use what the runner's host already has: its own AWS credentials for
`s3://dandiarchive-inventory`, and `snapshots/restic` with its password file under `/mnt/s3-logs/dandi-s3-logs`.
