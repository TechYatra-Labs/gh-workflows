#!/usr/bin/env bash
set -Eeuo pipefail

for variable in SSH_HOST SSH_USER; do
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

ssh_destination="$SSH_USER@$SSH_HOST"
if [[ "$SSH_HOST" == *:* ]]; then
  ssh_destination="$SSH_USER@[$SSH_HOST]"
fi

ssh -T -- "$ssh_destination" 'bash -se' <<'REMOTE_SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail

printf '%s\n' \
  '========================================' \
  'Prune Unused Docker Images' \
  '========================================'

docker image prune --all --force
REMOTE_SCRIPT
