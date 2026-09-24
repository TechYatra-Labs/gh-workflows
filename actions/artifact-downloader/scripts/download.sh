#!/usr/bin/env bash
set -Eeuo pipefail

for variable in INPUT_PROVIDER INPUT_BUCKET INPUT_REGION INPUT_SOURCE INPUT_DESTINATION; do
  if [[ -z "${!variable:-}" ]]; then
    printf '::error::Required input %s is empty.\n' "${variable#INPUT_}" >&2
    exit 2
  fi
done
command -v aws >/dev/null 2>&1 || {
  printf '::error::AWS CLI is required but was not found.\n' >&2
  exit 1
}
case "$INPUT_PROVIDER" in aws|digitalocean) ;; *)
  printf '::error::provider must be aws or digitalocean.\n' >&2; exit 2;;
esac
case "$INPUT_ARTIFACT_TYPE" in file|directory) ;; *)
  printf '::error::artifact-type must be file or directory.\n' >&2; exit 2;;
esac
for value in "$INPUT_BUCKET" "$INPUT_REGION" "$INPUT_SOURCE"; do
  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
    printf '::error::bucket, region, and source cannot contain newlines.\n' >&2
    exit 2
  fi
done
if [[ -n "$INPUT_ACCESS_KEY_ID" || -n "$INPUT_SECRET_ACCESS_KEY" ]]; then
  if [[ -z "$INPUT_ACCESS_KEY_ID" || -z "$INPUT_SECRET_ACCESS_KEY" ]]; then
    printf '::error::access-key-id and secret-access-key must be supplied together.\n' >&2
    exit 2
  fi
  export AWS_ACCESS_KEY_ID="$INPUT_ACCESS_KEY_ID"
  export AWS_SECRET_ACCESS_KEY="$INPUT_SECRET_ACCESS_KEY"
fi
[[ -z "$INPUT_SESSION_TOKEN" ]] || export AWS_SESSION_TOKEN="$INPUT_SESSION_TOKEN"
export AWS_DEFAULT_REGION="$INPUT_REGION"

endpoint="$INPUT_ENDPOINT_URL"
if [[ "$INPUT_PROVIDER" == digitalocean && -z "$endpoint" ]]; then
  endpoint="https://${INPUT_REGION}.digitaloceanspaces.com"
fi

source_key="${INPUT_SOURCE#/}"
storage_uri="s3://${INPUT_BUCKET}/${source_key}"
aws_args=(s3 cp)
if [[ "$INPUT_ARTIFACT_TYPE" == directory ]]; then
  aws_args+=(--recursive)
  mkdir -p "$INPUT_DESTINATION"
else
  mkdir -p "$(dirname "$INPUT_DESTINATION")"
fi
[[ -z "$endpoint" ]] || aws_args+=(--endpoint-url "$endpoint")
aws "${aws_args[@]}" "$storage_uri" "$INPUT_DESTINATION"

{
  printf 'storage-uri=%s\n' "$storage_uri"
  printf 'local-path=%s\n' "$INPUT_DESTINATION"
} >> "$GITHUB_OUTPUT"
printf 'Downloaded %s to %s\n' "$storage_uri" "$INPUT_DESTINATION"
