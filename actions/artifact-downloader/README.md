# Artifact downloader

Downloads any single file or complete directory prefix from AWS S3 or DigitalOcean Spaces. Set `artifact-type: directory` when downloading a directory such as a previously uploaded `dist/` tree.

The runner must have Bash and AWS CLI v2. Both are available on GitHub-hosted Ubuntu runners.

## Inputs and outputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `provider` | No | `aws` | `aws` or `digitalocean`. |
| `bucket` | Yes | — | Bucket or Space name. |
| `region` | Yes | — | AWS region or Spaces region such as `nyc3`. |
| `source` | Yes | — | Remote object key or directory prefix. |
| `destination` | Yes | — | Local output file or directory. |
| `artifact-type` | No | `file` | `file` or `directory`. |
| `access-key-id` | No | Existing credentials | Static access key. |
| `secret-access-key` | No | Existing credentials | Static secret key. |
| `session-token` | No | — | Temporary AWS session token. |
| `endpoint-url` | No | Provider default | Custom S3-compatible endpoint. |

Outputs: `storage-uri` and `local-path`.

## AWS S3 with GitHub OIDC

Configure an AWS IAM OIDC provider and a repository-restricted role with `s3:GetObject` access. The workflow must grant `id-token: write` so the credential action can exchange GitHub's token for temporary AWS credentials.

```yaml
jobs:
  download:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - name: Authenticate to AWS with OIDC
        uses: aws-actions/configure-aws-credentials@v5
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Download complete dist directory
        uses: techyatra-labs/gh-workflows/actions/artifact-downloader@main
        with:
          provider: aws
          bucket: my-build-artifacts
          region: us-east-1
          source: releases/${{ github.sha }}/
          destination: dist/
          artifact-type: directory
```

For one file, leave `artifact-type` at its default:

```yaml
- name: Download archive
  uses: techyatra-labs/gh-workflows/actions/artifact-downloader@main
  with:
    provider: aws
    bucket: my-build-artifacts
    region: us-east-1
    source: releases/${{ github.sha }}/release.zip
    destination: downloads/release.zip
```

## DigitalOcean Spaces authentication

DigitalOcean Spaces does **not currently support GitHub OIDC for S3 object requests**. Store a read-only, bucket-scoped Spaces key in GitHub secrets and pass it to the action:

```yaml
- name: Download dist from DigitalOcean Spaces
  uses: techyatra-labs/gh-workflows/actions/artifact-downloader@main
  with:
    provider: digitalocean
    bucket: my-build-artifacts
    region: nyc3
    source: releases/${{ github.sha }}/
    destination: dist/
    artifact-type: directory
    access-key-id: ${{ secrets.SPACES_ACCESS_KEY_ID }}
    secret-access-key: ${{ secrets.SPACES_SECRET_ACCESS_KEY }}
```

DigitalOcean reference: [Manage access to Spaces](https://docs.digitalocean.com/products/spaces/how-to/manage-access/). AWS reference: [OIDC federation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html).

For production workflows, pin actions to release tags or commit SHAs instead of `main`.
