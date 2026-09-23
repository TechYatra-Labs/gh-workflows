# Docker Compose status

This composite action connects to a remote server and runs `docker compose ps` for a supplied Compose project. It reports container state and fails on SSH, directory, missing-file, or Docker Compose errors. It does not deploy, restart, or modify containers.

> `docker compose ps` reports status; it is not an application health check and does not necessarily fail when a container is unhealthy or exited.

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `ssh-host` | Yes | — | Remote VM hostname or IP address. |
| `ssh-user` | Yes | — | SSH user. |
| `project-dir` | Yes | — | Absolute path to the remote Compose project. |
| `compose-file` | No | `docker-compose.yml` | Compose file relative to `project-dir`. |

The caller must configure an SSH agent and `known_hosts` before using the action.

```yaml
- name: Show deployment status
  uses: techyatra-labs/.github/actions/docker-compose-status@main
  with:
    ssh-host: ${{ secrets.VM_HOST }}
    ssh-user: ${{ secrets.VM_USER }}
    project-dir: /srv/Projects/erp-school
    compose-file: docker-compose.yml
```
