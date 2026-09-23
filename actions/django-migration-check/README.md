# Django migration check

This composite action validates Django migration history on an existing remote Docker Compose deployment. It supports Django's `migrate` command and django-tenants' `migrate_schemas` command.

The action validates the Compose configuration and runs the selected migration command with `--plan`. It does **not** apply migrations, change database state, pull images, restart containers, authenticate to a registry, deploy, or roll back anything.

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `ssh-host` | Yes | — | Remote VM hostname or IP address. |
| `ssh-user` | Yes | — | SSH user. |
| `project-dir` | Yes | — | Absolute remote path containing the Compose project. |
| `compose-file` | No | `docker-compose.yml` | Compose file relative to `project-dir`. |
| `service` | No | `web` | Compose service containing Django. |
| `migration-command` | No | `migrate_schemas` | Migration command. Accepted values are `migrate` and `migrate_schemas`. |

## Caller setup and usage

The caller must load its SSH key into an agent and add the server to `known_hosts` before invoking this action. The action does not accept or store private keys and does not disable SSH host-key verification.

```yaml
- name: Setup SSH
  uses: webfactory/ssh-agent@v0.9.0
  with:
    ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}

- name: Add known host
  shell: bash
  run: |
    mkdir -p ~/.ssh
    ssh-keyscan -H "${{ secrets.VM_HOST }}" >> ~/.ssh/known_hosts

- name: Validate Django migrations
  uses: techyatra-labs/.github/actions/django-migration-check@v1
  with:
    ssh-host: ${{ secrets.VM_HOST }}
    ssh-user: ${{ secrets.VM_USER }}
    project-dir: /srv/Projects/erp-school
    compose-file: docker-compose.yml
    service: web
    migration-command: migrate_schemas
```

Use `migration-command: migrate` for standard Django projects. For django-tenants projects, the default `migrate_schemas` command can print multiple `=== Starting migration` and `Planned operations:` sections while inspecting tenant schemas. Repeated sections are expected and are not treated as errors.

## Non-interactive behavior

The remote Compose command includes `--interactive=false` and redirects standard input from `/dev/null`. Both safeguards are intentional: they prevent Docker Compose from consuming the SSH heredoc in a non-interactive GitHub Actions session. Removing either safeguard can cause the remaining remote script to be consumed without producing the expected failure status.

SSH is invoked with `-T`, so it does not allocate a pseudo-terminal. Any Compose validation, Docker, or migration-planning failure is returned to the caller and fails the action.

## Versioning

Production callers should pin a supported major tag such as `@v1`, or use an immutable commit SHA for the strongest reproducibility. Move the `v1` tag when publishing compatible `1.x` releases.
