# Email artifact link

This composite action sends a plain-text build notification through the Tech Yatra bulk mail API. By default, an email delivery failure produces a workflow warning without failing the build.

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `api-key` | Yes | — | Mail API authentication key. Pass it from a GitHub Actions secret. |
| `recipients` | Yes | — | Comma- or newline-separated email addresses. |
| `subject` | Yes | — | Email subject. |
| `body` | Yes | — | Plain-text email body. |
| `api-url` | No | Tech Yatra bulk endpoint | Mail API endpoint. |
| `fail-on-error` | No | `false` | Set to `true` to fail the workflow when delivery fails. |

The runner must provide Bash, `curl`, and `jq`. All are preinstalled on GitHub-hosted Ubuntu runners.

## Usage

```yaml
- name: Email artifact link
  uses: techyatra-labs/gh-workflows/actions/email-artifact-link@main
  with:
    api-key: ${{ secrets.MAIL_API_KEY }}
    recipients: |
      dev.techyatralabs@gmail.com
    subject: TeacherOs build ${{ github.run_number }} is ready
    body: |
      Hello,

      The Android APK is ready to download:
      ${{ steps.upload.outputs.artifact-url }}

      View the build run:
      ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

For production workflows, pin the action to a release tag or commit SHA instead of `main`.
