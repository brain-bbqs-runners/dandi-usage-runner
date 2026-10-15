<p align="center">
  <img src="docs/branding/dandi-runner.svg" width="250" alt="DANDI usage runner logo"/>

  <h1 align="center">DANDI Usage (Runner)</h1>
</p>

GitHub Action-controlled CRON jobs that generate the DANDI access summaries on the self-hosted Typhon runner
(moved from [CodyCBakerPhD/self-hosted-crons](https://github.com/CodyCBakerPhD/self-hosted-crons)).
The extraction commands and the upload run through
[CodyCBakerPhD/dandi-s3-logs-action](https://github.com/CodyCBakerPhD/dandi-s3-logs-action) `@v1`,
and the pre-run check through [CodyCBakerPhD/check-runner-action](https://github.com/CodyCBakerPhD/check-runner-action) `@v1`.

| Workflow | Schedule |
| --- | --- |
| Update DANDI summaries | Sundays, Wednesdays and Saturdays, 06:00 UTC |
| Update microscopy summaries (DANDI:000108) | Mondays, 06:00 UTC |
| Update unassociated DANDI summaries | 1st of each month, 03:00 UTC |

## Configuration

A self-hosted runner with the labels `typhon` and `dandi` must be registered to this repository.

Repository variables:

- `DANDI_S3_LOG_BASE_PATH`
- `S3LOGS_ENV_NAME`

Repository secrets:

- `S3_LOG_EXTRACTION_PASSWORD`
- `MAXMIND_ACCOUNT_ID` / `MAXMIND_LICENSE_KEY`
- `_GITHUB_API_KEY` (token able to list this repository's runners, for the pre-run check)
- `MAIL_USERNAME` / `MAIL_PASSWORD` (failure notifications)
