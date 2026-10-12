#!/usr/bin/env bash
set -euo pipefail

# Default to the working API endpoint if not explicitly provided
MAIL_API_URL="${MAIL_API_URL:-https://mailserver.techyatralabs.com/v1/emails}"

# Validate required inputs
if [[ -z "${MAIL_API_KEY:-}" ]]; then
  echo "::error::The api-key input must not be empty."
  exit 1
fi

if [[ -z "${MAIL_RECIPIENTS:-}" ]]; then
  echo "::error::At least one recipient is required."
  exit 1
fi

# Convert recipients into JSON array
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

recipient_count="$(jq 'length' <<< "$recipients")"

if [[ "$recipient_count" -eq 0 ]]; then
  echo "::error::At least one valid recipient is required."
  exit 1
fi

BODY_TYPE="${MAIL_BODY_TYPE:-plain}"
if [[ "${MAIL_BODY:-}" =~ "<!DOCTYPE" || "${MAIL_BODY:-}" =~ "<html" ]]; then
  BODY_TYPE="html"
fi

# Build JSON payload directly into a variable
payload="$(jq -nc \
  --argjson recipient_email "$recipients" \
  --arg subject "${MAIL_SUBJECT:-TeacherOS Notification}" \
  --arg body "${MAIL_BODY:-}" \
  --arg body_type "$BODY_TYPE" \
  --arg from_email "${MAIL_FROM_EMAIL:-apk-release@techyatralabs.com}" \
  --arg from_name "${MAIL_FROM_NAME:-APP Developer}" \
  --arg reply_to "${MAIL_REPLY_TO:-apk-release@techyatralabs.com}" \
  '{
    recipient_email: $recipient_email,
    subject: $subject,
    body: $body,
    body_type: $body_type,
    from_email: $from_email,
    from_name: $from_name,
    reply_to: $reply_to
  }')"

echo "Sending email to ${recipient_count} recipient(s)..."
echo "Target endpoint: $MAIL_API_URL"
echo "Payload: $payload"

response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

http_code="$(
  curl \
    --silent \
    --show-error \
    --output "$response_file" \
    --write-out '%{http_code}' \
    --request POST \
    --url "$MAIL_API_URL" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --header "x-api-key: $MAIL_API_KEY" \
    --data-raw "$payload"
)"

echo "Mail API HTTP Status: $http_code"
echo "Mail API response:"
cat "$response_file" || true
echo

if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
  echo "Email notification sent successfully."
  exit 0
fi

message="Mail API returned HTTP ${http_code}."
if [[ "${FAIL_ON_ERROR:-false}" == "true" ]]; then
  echo "::error::$message"
  exit 1
else
  echo "::warning::$message"
fi
