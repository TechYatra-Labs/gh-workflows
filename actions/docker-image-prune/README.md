# Docker image prune

This composite action connects to a remote server and runs:

```bash
docker image prune --all --force
```

This permanently removes every Docker image not referenced by a container. Running containers and their images are not removed, but unused images may need to be downloaded again during a future deployment.

## Inputs

| Input | Required | Description |
| --- | --- | --- |
| `ssh-host` | Yes | Remote VM hostname or IP address. |
| `ssh-user` | Yes | SSH user. |

The caller must configure an SSH agent and `known_hosts` before using the action.

```yaml
- name: Clean old Docker images
  if: success()
  uses: techyatra-labs/.github/actions/docker-image-prune@main
  with:
    ssh-host: ${{ secrets.VM_HOST }}
    ssh-user: ${{ secrets.VM_USER }}
```
