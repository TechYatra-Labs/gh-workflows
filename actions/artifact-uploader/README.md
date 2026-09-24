# Artifact uploader

Uploads any single file or complete directory to AWS S3 or DigitalOcean Spaces. Directories such as `dist/`, `build/`, coverage reports, and documentation sites are detected automatically and uploaded recursively, including nested files.

The runner must have Bash and AWS CLI v2. Both are available on GitHub-hosted Ubuntu runners.

## Inputs and outputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `provider` | No | `aws` | `aws` or `digitalocean`. |
| `bucket` | Yes | — | Bucket or Space name. |
| `region` | Yes | — | AWS region or Spaces region such as `nyc3`. |
| `source` | Yes | — | Any local file or directory. |
| `destination` | No | Source basename | Remote object key or directory prefix. |
| `access-key-id` | No | Existing credentials | Static access key. |
| `secret-access-key` | No | Existing credentials | Static secret key. |
| `session-token` | No | — | Temporary AWS session token. |
| `endpoint-url` | No | Provider default | Custom S3-compatible endpoint. |
| `acl` | No | — | Optional upload ACL such as `public-read`. |
| `presign-expiry` | No | `0` | Generate a temporary file URL valid for this many seconds. |

Outputs: `storage-uri`, `artifact-url`, and `artifact-type`. Directory uploads do not produce an artifact URL because they contain multiple objects.

## AWS S3 with GitHub OIDC

AWS supports GitHub OIDC, so no permanent AWS keys are required. Configure an AWS IAM OIDC provider and a role restricted to your organization/repository, grant it `s3:PutObject` for the destination, and store the role ARN as `AWS_ROLE_ARN`.

```yaml
jobs:
  build-and-upload:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4

      - run: npm ci && npm run build

      - name: Authenticate to AWS with OIDC
        uses: aws-actions/configure-aws-credentials@v5
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Upload complete dist directory
        uses: techyatra-labs/gh-workflows/actions/artifact-uploader@main
        with:
          provider: aws
          bucket: my-build-artifacts
          region: us-east-1
          source: dist/
          destination: releases/${{ github.sha }}/
```

For a single private file and a temporary download link:

```yaml
- name: Upload archive
  id: upload
  uses: techyatra-labs/gh-workflows/actions/artifact-uploader@main
  with:
    provider: aws
    bucket: my-build-artifacts
    region: us-east-1
    source: release.zip
    destination: releases/${{ github.sha }}/release.zip
    presign-expiry: "86400"

- run: echo "${{ steps.upload.outputs.artifact-url }}"
```

## DigitalOcean Spaces authentication

DigitalOcean Spaces does **not currently support GitHub OIDC for S3 object requests**. Spaces requires a Spaces access-key pair. Create a bucket-scoped key in DigitalOcean, save it as the GitHub secrets `SPACES_ACCESS_KEY_ID` and `SPACES_SECRET_ACCESS_KEY`, and use:

```yaml
- uses: actions/checkout@v4

- run: npm ci && npm run build

- name: Upload dist to DigitalOcean Spaces
  uses: techyatra-labs/gh-workflows/actions/artifact-uploader@main
  with:
    provider: digitalocean
    bucket: my-build-artifacts
    region: nyc3
    source: dist/
    destination: releases/${{ github.sha }}/
    access-key-id: ${{ secrets.SPACES_ACCESS_KEY_ID }}
    secret-access-key: ${{ secrets.SPACES_SECRET_ACCESS_KEY }}
```

DigitalOcean reference: [Manage access to Spaces](https://docs.digitalocean.com/products/spaces/how-to/manage-access/). AWS reference: [OIDC federation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html).

For production workflows, pin actions to release tags or commit SHAs instead of `main`.
