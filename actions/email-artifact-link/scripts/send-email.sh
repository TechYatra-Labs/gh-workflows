#!/usr/bin/env bash
set -euo pipefail

payload_file="$(mktemp)"
trap 'rm -f "$payload_file"' EXIT

if [[ -z "$MAIL_API_KEY" ]]; then
  echo "::error::The api-key input must not be empty."
  exit 1
fi

if [[ -z "$MAIL_RECIPIENTS" ]]; then
  echo "::error::At least one recipient is required."
  exit 1
fi

case "$FAIL_ON_ERROR" in
  true|false)
    ;;
  *)
    echo "::error::The fail-on-error input must be either 'true' or 'false'."
    exit 1
    ;;
esac

# Convert comma/newline-separated recipients into a JSON array.
recipients="$(
  printf '%s\n' "$MAIL_RECIPIENTS" |
    jq -Rsc '
      split("\n")
      | map(split(","))
      | flatten
      | map(gsub("^[[:space:]]+|[[:space:]]+$"; ""))
      | map(select(length > 0))
    '
)"

if [[ "$(jq 'length' <<<"$recipients")" -eq 0 ]]; then
  echo "::error::At least one recipient is required."
  exit 1
fi

# Build payload according to the Tech Yatra Mail API.
jq -n \
  --arg from_email "$MAIL_FROM_EMAIL" \
  --arg from_name "$MAIL_FROM_NAME" \
  --argjson recipient_email "$recipients" \
  --arg subject "$MAIL_SUBJECT" \
  --arg body "$MAIL_BODY" \
  --arg reply_to "$MAIL_REPLY_TO" \
  '{
    from_email: $from_email,
    from_name: $from_name,
    recipient_email: $recipient_email,
    subject: $subject,
    body: $body,
    body_type: "text",
    reply_to: $reply_to
  }' > "$payload_file"

echo "Sending email to $(jq 'length' <<<"$recipients") recipient(s)..."

if curl --fail-with-body \
  --silent \
  --show-error \
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
