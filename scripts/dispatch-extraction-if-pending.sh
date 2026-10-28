#!/usr/bin/env bash
# Dispatch the DANDI log extraction workflow only when there are log files left to extract.
#
# Meant for the crontab of the Typhon host, so that the extraction runner is not started on days the
# inventory has nothing new. See the README for the crontab line and the token it reads.
set -euo pipefail

BASE_PATH="${S3_LOG_BASE_PATH:-/mnt/s3-logs/dandi-s3-logs}"
TOKEN_FILE="${DISPATCH_TOKEN_FILE:-$BASE_PATH/.github-dispatch-token}"
REPOSITORY="brain-bbqs-runners/dandi-usage-runner"
# The '+' of the workflow file name must be percent-encoded in the API path.
WORKFLOW="name-run%2Bextraction_archive-dandi_runner-typhon_trigger-cron%2Bdispatch_freq-daily.yml"
# `extract --check` exits with this when log files are pending, and 1 on an error.
PENDING_STATUS=3
# flock exits with this when another run holds the lock, which tells it apart from the check's own statuses.
LOCK_HELD_STATUS=75

log() {
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*"
}

[ -r "$TOKEN_FILE" ] || { log "Cannot read the dispatch token at $TOKEN_FILE."; exit 1; }

# The check is the workflow's own extraction command plus `--check`, so it reads exactly what a run would.
# It holds the same lock as the extraction, so it never reads the records while a run writes them.
status=0
flock -n -E "$LOCK_HELD_STATUS" "$BASE_PATH/flocks/s3logextraction.lock" \
    "$BASE_PATH/env/bin/dandis3logextraction" extract s3://dandiarchive-logs \
    --mode remote \
    --inventory "$BASE_PATH/inventory" \
    --cache "$BASE_PATH/extraction_cache" \
    --limit 1000000 \
    --check || status=$?

case "$status" in
    0)
        log "No log files are pending extraction. Not dispatching."
        exit 0
        ;;
    "$LOCK_HELD_STATUS")
        log "Another run holds the extraction lock. Not dispatching."
        exit 0
        ;;
    "$PENDING_STATUS")
        log "Log files are pending extraction. Dispatching the workflow."
        ;;
    *)
        # A failed check, such as corrupted extraction records, is dispatched too. The workflow then fails
        # where its failure notification reports it, rather than only in this log.
        log "The pending check failed with status $status. Dispatching the workflow so the failure surfaces there."
        ;;
esac

# The token is passed as a header file, so that it never appears in the process list.
curl --fail-with-body --silent --show-error \
    --request POST \
    --header "Accept: application/vnd.github+json" \
    --header "X-GitHub-Api-Version: 2022-11-28" \
    --header @<(printf 'Authorization: Bearer %s\n' "$(< "$TOKEN_FILE")") \
    --data '{"ref":"main"}' \
    "https://api.github.com/repos/$REPOSITORY/actions/workflows/$WORKFLOW/dispatches"
log "Dispatched."
