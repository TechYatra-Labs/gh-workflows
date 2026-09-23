#!/usr/bin/env bash
set -Eeuo pipefail

required_variables=(
  SSH_HOST
  SSH_USER
  PROJECT_DIR
  COMPOSE_FILE
  SERVICE
  MIGRATION_COMMAND
)

for variable in "${required_variables[@]}"; do
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

if [[ ! "$SERVICE" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
  printf 'Error: SERVICE must be a valid Docker Compose service name.\n' >&2
  exit 2
fi

case "$MIGRATION_COMMAND" in
  migrate|migrate_schemas) ;;
  *)
    printf 'Error: MIGRATION_COMMAND must be either migrate or migrate_schemas.\n' >&2
    exit 2
    ;;
esac

printf '%s\n' \
  '========================================' \
  'Django Migration Validation' \
  '========================================'
printf 'Host: %s\n' "$SSH_HOST"
printf 'Project: %s\n' "$PROJECT_DIR"
printf 'Compose file: %s\n' "$COMPOSE_FILE"
printf 'Service: %s\n' "$SERVICE"
printf 'Migration command: %s\n\n' "$MIGRATION_COMMAND"

# %q preserves each value as one Bash argument when SSH invokes the remote shell.
printf -v remote_command 'bash -se -- %q %q %q %q' \
  "$PROJECT_DIR" "$COMPOSE_FILE" "$SERVICE" "$MIGRATION_COMMAND"

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
SERVICE=$3
MIGRATION_COMMAND=$4

cd "$PROJECT_DIR"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  printf 'Error: Compose file does not exist: %s/%s\n' "$PROJECT_DIR" "$COMPOSE_FILE" >&2
  exit 1
fi

printf 'Validating Docker Compose...\n'
docker compose -f "$COMPOSE_FILE" config --quiet
printf 'Docker Compose valid.\n\n'

printf 'Checking migration history...\n'
docker compose \
  -f "$COMPOSE_FILE" \
  run \
  --rm \
  --no-deps \
  --interactive=false \
  --entrypoint python \
  "$SERVICE" \
  manage.py \
  "$MIGRATION_COMMAND" \
  --plan \
  < /dev/null

printf '\nMigration validation successful.\n'
REMOTE_SCRIPT
