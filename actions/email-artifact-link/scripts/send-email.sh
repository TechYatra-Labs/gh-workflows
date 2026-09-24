#!/usr/bin/env bash
set -euo pipefail

payload_file="$(mktemp)"
trap 'rm -f "$payload_file"' EXIT

if [[ -z "$MAIL_API_KEY" ]]; then
  echo "::error::The api-key input must not be empty."
  exit 1
fi

case "$FAIL_ON_ERROR" in
  true|false) ;;
  *)
    echo "::error::The fail-on-error input must be either 'true' or 'false'."
    exit 1
    ;;
esac

recipients="$({ printf '%s\n' "$MAIL_RECIPIENTS"; } | jq -Rsc '
  split("\n")
  | map(split(","))
  | flatten
  | map(gsub("^[[:space:]]+|[[:space:]]+$"; ""))
  | map(select(length > 0))
')"

if [[ "$(jq 'length' <<<"$recipients")" -eq 0 ]]; then
  echo "::error::At least one recipient is required."
  exit 1
fi

jq -n \
  --argjson recipients "$recipients" \
  --arg subject "$MAIL_SUBJECT" \
  --arg body "$MAIL_BODY" \
  '{recipients: $recipients, subject: $subject, body: $body}' \
  > "$payload_file"

if curl --fail-with-body --silent --show-error \
  --retry 2 \
  --request POST "$MAIL_API_URL" \
  --header "Content-Type: application/json" \
  --header "X-API-Key: $MAIL_API_KEY" \
  --data-binary "@$payload_file"; then
  echo "Email notification sent to $(jq 'length' <<<"$recipients") recipient(s)."
else
  if [[ "$FAIL_ON_ERROR" == "true" ]]; then
    echo "::error::Failed to send the email notification."
    exit 1
  fi

  echo "::warning::Failed to send the email notification."
fi
