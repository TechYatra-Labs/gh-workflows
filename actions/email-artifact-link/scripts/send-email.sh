#!/usr/bin/env bash
set -euo pipefail

payload_file="$(mktemp)"
response_file="$(mktemp)"

trap 'rm -f "$payload_file" "$response_file"' EXIT

# Validate required inputs
if [[ -z "${MAIL_API_KEY:-}" ]]; then
  echo "::error::The api-key input must not be empty."
  exit 1
fi

if [[ -z "${MAIL_RECIPIENTS:-}" ]]; then
  echo "::error::At least one recipient is required."
  exit 1
fi

if [[ -z "${MAIL_API_URL:-}" ]]; then
  echo "::error::MAIL_API_URL is required."
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

# Convert comma/newline-separated recipients into JSON array
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

# Build payload expected by Tech Yatra Mail API
jq -n \
  --argjson recipient_email "$recipients" \
  --arg subject "${MAIL_SUBJECT:-}" \
  --arg body "${MAIL_BODY:-}" \
  --arg from_email "${MAIL_FROM_EMAIL:-notifications@techyatralabs.com}" \
  --arg from_name "${MAIL_FROM_NAME:-Tech Yatra}" \
  --arg reply_to "${MAIL_REPLY_TO:-support@techyatralabs.com}" \
  '{
    recipient_email: $recipient_email,
    subject: $subject,
    body: $body,
    body_type: "html",
    from_email: $from_email,
    from_name: $from_name,
    reply_to: $reply_to
  }' > "$payload_file"

# Ensure payload exists and is valid JSON
if [[ ! -s "$payload_file" ]]; then
  echo "::error::Generated email payload is empty."
  exit 1
fi

if ! jq -e . "$payload_file" >/dev/null; then
  echo "::error::Generated email payload is invalid JSON."
  exit 1
fi

echo "Sending email to ${recipient_count} recipient(s)..."
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

echo "Mail API response:"
cat "$response_file" || true
echo

if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
  echo "Email notification sent successfully to ${recipient_count} recipient(s)."
  exit 0
fi

message="Mail API returned HTTP ${http_code}."

if [[ "$FAIL_ON_ERROR" == "true" ]]; then
  echo "::error::$message"
  exit 1
else
  echo "::warning::$message"
fi
