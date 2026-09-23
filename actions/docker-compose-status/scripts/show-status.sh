#!/usr/bin/env bash
set -Eeuo pipefail

for variable in SSH_HOST SSH_USER PROJECT_DIR COMPOSE_FILE; do
  if [[ -z "${!variable:-}" ]]; then
    printf 'Error: required environment variable %s is empty or unset.\n' "$variable" >&2
    exit 2
  fi
done

if [[ ! "$SSH_HOST" =~ ^[A-Za-z0-9._:-]+$ ]]; then
  printf 'Error: SSH_HOST contains unsupported characters.\n' >&2
  exit 2
fi

if [[ ! "$SSH_USER" =~ ^[A-Za-z0-9._-]+$ ]]; then
  printf 'Error: SSH_USER contains unsupported characters.\n' >&2
  exit 2
fi

if [[ "$PROJECT_DIR" != /* || "$PROJECT_DIR" == *$'\n'* || "$PROJECT_DIR" == *$'\r'* ]]; then
  printf 'Error: PROJECT_DIR must be an absolute path without newline characters.\n' >&2
  exit 2
fi

if [[ "$COMPOSE_FILE" == /* || "$COMPOSE_FILE" == *$'\n'* || "$COMPOSE_FILE" == *$'\r'* ]]; then
  printf 'Error: COMPOSE_FILE must be a relative path without newline characters.\n' >&2
  exit 2
fi

printf -v remote_command 'bash -se -- %q %q' "$PROJECT_DIR" "$COMPOSE_FILE"

ssh_destination="$SSH_USER@$SSH_HOST"
if [[ "$SSH_HOST" == *:* ]]; then
  ssh_destination="$SSH_USER@[$SSH_HOST]"
fi

# shellcheck disable=SC2029 # The values are deliberately escaped with Bash %q above.
ssh -T -- "$ssh_destination" "$remote_command" <<'REMOTE_SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR=$1
COMPOSE_FILE=$2

cd "$PROJECT_DIR"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  printf 'Error: Compose file does not exist: %s/%s\n' "$PROJECT_DIR" "$COMPOSE_FILE" >&2
  exit 1
fi

printf '%s\n' \
  '========================================' \
  'Docker Compose Status' \
  '========================================'
printf 'Host: %s\n' "$(hostname)"
printf 'Project: %s\n' "$PROJECT_DIR"
printf 'Compose file: %s\n\n' "$COMPOSE_FILE"

docker compose -f "$COMPOSE_FILE" ps
REMOTE_SCRIPT
