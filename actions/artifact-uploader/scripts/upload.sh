#!/usr/bin/env bash
set -Eeuo pipefail

for variable in INPUT_PROVIDER INPUT_BUCKET INPUT_REGION INPUT_SOURCE; do
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
if [[ ! "$INPUT_PRESIGN_EXPIRY" =~ ^[0-9]+$ ]]; then
  printf '::error::presign-expiry must be a non-negative integer.\n' >&2
  exit 2
fi
for value in "$INPUT_BUCKET" "$INPUT_REGION" "$INPUT_DESTINATION"; do
  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
    printf '::error::bucket, region, and destination cannot contain newlines.\n' >&2
    exit 2
  fi
done
if [[ ! -e "$INPUT_SOURCE" ]]; then
  printf '::error::Source does not exist: %s\n' "$INPUT_SOURCE" >&2
  exit 1
fi
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

source_path="${INPUT_SOURCE%/}"
destination="${INPUT_DESTINATION#/}"
if [[ -z "$destination" ]]; then
  destination="$(basename "$source_path")"
fi
artifact_type="file"
aws_args=(s3 cp)
if [[ -d "$source_path" ]]; then
  artifact_type="directory"
  destination="${destination%/}/"
  aws_args+=(--recursive)
elif [[ "$destination" == */ ]]; then
  destination+="$(basename "$source_path")"
fi
[[ -z "$endpoint" ]] || aws_args+=(--endpoint-url "$endpoint")
[[ -z "$INPUT_ACL" ]] || aws_args+=(--acl "$INPUT_ACL")

storage_uri="s3://${INPUT_BUCKET}/${destination}"
aws "${aws_args[@]}" "$source_path" "$storage_uri"

urlencode_key() {
  local LC_ALL=C character encoded="" index
  for ((index = 0; index < ${#1}; index++)); do
    character="${1:index:1}"
    case "$character" in
      [A-Za-z0-9._~/-]) encoded+="$character" ;;
      *) printf -v encoded '%s%%%02X' "$encoded" "'$character" ;;
    esac
  done
  printf '%s' "$encoded"
}

artifact_url=""
if [[ "$artifact_type" == file ]]; then
  if (( INPUT_PRESIGN_EXPIRY > 0 )); then
    presign_args=(s3 presign "$storage_uri" --expires-in "$INPUT_PRESIGN_EXPIRY")
    [[ -z "$endpoint" ]] || presign_args+=(--endpoint-url "$endpoint")
    artifact_url="$(aws "${presign_args[@]}")"
  else
    encoded_destination="$(urlencode_key "$destination")"
    if [[ "$INPUT_PROVIDER" == digitalocean ]]; then
      artifact_url="https://${INPUT_BUCKET}.${INPUT_REGION}.digitaloceanspaces.com/${encoded_destination}"
    else
      artifact_url="https://${INPUT_BUCKET}.s3.${INPUT_REGION}.amazonaws.com/${encoded_destination}"
    fi
  fi
fi

{
  printf 'storage-uri=%s\n' "$storage_uri"
  printf 'artifact-url=%s\n' "$artifact_url"
  printf 'artifact-type=%s\n' "$artifact_type"
} >> "$GITHUB_OUTPUT"
printf 'Uploaded %s to %s\n' "$artifact_type" "$storage_uri"
