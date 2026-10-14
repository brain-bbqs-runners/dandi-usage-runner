#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <org_or_repo> <labels_comma_separated>"
  exit 1
fi

target="$1"
labels="$2"

if ! command -v gh &> /dev/null; then
  echo "Error: GitHub CLI (gh) is not installed." >&2
  exit 1
fi
if [[ "$target" == *"/"* ]]; then
  endpoint="repos/$target/actions/runners"
else
  endpoint="orgs/$target/actions/runners"
fi
response=$(gh api "$endpoint" 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "Error: API call failed at $endpoint" >&2
  exit 1
fi

# Split labels by comma into an array
IFS=',' read -ra label_array <<< "$labels"

# Build jq filter to check if runner has all required labels
available=$(echo "$response" | jq -r --argjson required_labels "$(printf '%s\n' "${label_array[@]}" | jq -R . | jq -s .)" '
  .runners[] | select(.status == "online") |
  select(
    ([.labels[].name] as $runner_labels |
     $required_labels | all(. as $req | $runner_labels | contains([$req])))
  )')

if [ -n "$available" ]; then
  echo "true"
else
  echo "false"
fi
