#!/usr/bin/env bash
set -euo pipefail

payload_file="$(mktemp)"
response_file="$(mktemp)"

trap 'rm -f "$payload_file" "$response_file"' EXIT

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

case "${FAIL_ON_ERROR:-false}" in
  true|false)
    ;;
  *)
    echo "::error::The fail-on-error input must be either 'true' or 'false'."
    exit 1
    ;;
esac

# Convert comma/newline-separated recipients into a clean JSON array
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

# Determine body type: check input or auto-detect HTML
BODY_TYPE="${MAIL_BODY_TYPE:-}"
if [[ -z "$BODY_TYPE" ]]; then
  if [[ "${MAIL_BODY:-}" =~ "<!DOCTYPE" || "${MAIL_BODY:-}" =~ "<html" ]]; then
    BODY_TYPE="html"
  else
    BODY_TYPE="plain"
  fi
fi

# Build JSON payload
jq -n \
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
  }' > "$payload_file"

# Validate generated JSON
if [[ ! -s "$payload_file" ]]; then
  echo "::error::Generated email payload is empty."
  exit 1
fi

if ! jq -e . "$payload_file" >/dev/null; then
  echo "::error::Generated email payload is invalid JSON."
  exit 1
fi

echo "Sending email to ${recipient_count} recipient(s)..."
echo "Target endpoint: $MAIL_API_URL"
echo "Payload size: $(wc -c < "$payload_file") bytes"

http_code="$(
  curl \
    --silent \
    --show-error \
    --output "$response_file" \
    --write-out '%{http_code}' \
    --retry 2 \
    --retry-delay 1 \
    --request POST \
    --url "$MAIL_API_URL" \
    --header "accept: */*" \
    --header "x-api-key: $MAIL_API_KEY" \
    --header "Content-Type: application/json" \
    --data-binary @"$payload_file"
)"

echo "Mail API HTTP Status: $http_code"
echo "Mail API response:"
cat "$response_file" || true
echo

if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
  echo "Email notification sent successfully to ${recipient_count} recipient(s)."
  exit 0
fi

message="Mail API returned HTTP ${http_code}."

if [[ "${FAIL_ON_ERROR:-false}" == "true" ]]; then
  echo "::error::$message"
  exit 1
else
  echo "::warning::$message"
fi
