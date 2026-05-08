# CI Setup

Add a `theodo-scan` job to an existing CI pipeline. Each per-provider snippet below runs on every push to the default branch (i.e. after a PR is merged) and uploads the SBOM to S3.

## How `theodo-scan` behaves in CI

When the standard `CI` environment variable is set (GitHub Actions, GitLab CI, Bitbucket Pipelines, CircleCI, Azure Pipelines, and most other providers set it automatically), `theodo-scan upload` ignores `THEODO_SCAN_LOCAL_AWS_PROFILE` / `--profile` and falls back to the default AWS credential chain. This lets you authenticate without long-lived AWS keys.

## AWS authentication

### Recommended: OIDC + per-CI IAM role

Each provider can issue an OIDC token that is exchanged for short-lived AWS credentials via `sts:AssumeRoleWithWebIdentity`. Scope the role's policy to the prefix the SBOM is uploaded to so each CI can only write to its own folder:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject"],
      "Resource": "arn:aws:s3:::<bucket>/sboms/<org>-<project>-<component>/*"
    }
  ]
}
```

Provider docs:
- GitHub Actions — [Configuring OpenID Connect in AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services). Use `aws-actions/configure-aws-credentials` with `role-to-assume`.
- GitLab CI — [Configure OpenID Connect with AWS](https://docs.gitlab.com/ee/ci/cloud_services/aws/). Use `aws sts assume-role-with-web-identity` with the GitLab-injected `CI_JOB_JWT_V2`.
- Bitbucket Pipelines — [Deploy on AWS using OpenID Connect](https://support.atlassian.com/bitbucket-cloud/docs/deploy-on-aws-using-bitbucket-pipelines-openid-connect/). Use the `oidc` step option.
- Azure Pipelines — Azure DevOps does not provide native AWS OIDC. Use an AWS service connection (see the [Azure Pipelines section](#azure-pipelines) below).

### Alternative: AWS access keys as CI secrets

Set `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and (optionally) `AWS_SESSION_TOKEN` and `AWS_REGION` as CI secrets. The AWS CLI picks them up automatically. OIDC is preferred since it avoids long-lived credentials.

## Prerequisites

Apply these steps once before configuring any provider:

1. **Commit a `.theodorc`** at the repo root. Run `theodo-scan init` locally and edit values, then commit the file.
2. **Configure AWS authentication** as described above. The IAM role used by CI needs `s3:PutObject` on `arn:aws:s3:::<bucket>/sboms/<org>-<project>-<component>/*`.
3. **Replace the placeholders** in the snippets below: `<AWS_ACCOUNT_ID>`, `<AWS_REGION>`, `<theodo-scan-role>`, and (Azure only) `<aws-service-connection>`.

---

## GitHub Actions

File: `.github/workflows/theodo-scan.yml`

```yaml
name: Theodo Scan

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  theodo-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: aquasecurity/setup-trivy@v0.2.0

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::<AWS_ACCOUNT_ID>:role/<theodo-scan-role>
          aws-region: <AWS_REGION>

      - name: Install theodo-scan
        run: |
          git clone --depth 1 https://github.com/theodo-group/theodo-scan.git "$HOME/theodo-scan"
          echo "$HOME/theodo-scan/bin" >> "$GITHUB_PATH"

      - name: Run theodo-scan
        run: theodo-scan run
```

`jq` and the AWS CLI are preinstalled on `ubuntu-latest`.

---

## GitLab CI

File: `.gitlab-ci.yml` (add the job to your existing file)

```yaml
theodo-scan:
  stage: test
  image: ubuntu:24.04
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  id_tokens:
    AWS_ID_TOKEN:
      aud: https://gitlab.com
  variables:
    AWS_REGION: <AWS_REGION>
    AWS_ROLE_ARN: arn:aws:iam::<AWS_ACCOUNT_ID>:role/<theodo-scan-role>
  before_script:
    - apt-get update && apt-get install -y --no-install-recommends bash ca-certificates curl git jq unzip
    - curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
    - curl -sfL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install
    - export AWS_WEB_IDENTITY_TOKEN_FILE="$(mktemp)" && printf '%s' "$AWS_ID_TOKEN" > "$AWS_WEB_IDENTITY_TOKEN_FILE"
  script:
    - git clone --depth 1 https://github.com/theodo-group/theodo-scan.git /tmp/theodo-scan
    - export PATH="/tmp/theodo-scan/bin:$PATH"
    - theodo-scan run
```

The AWS SDK reads `AWS_ROLE_ARN` + `AWS_WEB_IDENTITY_TOKEN_FILE` and assumes the role automatically.

---

## Bitbucket Pipelines

File: `bitbucket-pipelines.yml` (add the step to your existing file)

```yaml
image: atlassian/default-image:4

pipelines:
  branches:
    main:
      - step:
          name: Theodo Scan
          oidc: true
          script:
            - export AWS_REGION=<AWS_REGION>
            - export AWS_ROLE_ARN=arn:aws:iam::<AWS_ACCOUNT_ID>:role/<theodo-scan-role>
            - export AWS_WEB_IDENTITY_TOKEN_FILE="$(mktemp)" && printf '%s' "$BITBUCKET_STEP_OIDC_TOKEN" > "$AWS_WEB_IDENTITY_TOKEN_FILE"
            - apt-get update && apt-get install -y --no-install-recommends jq
            - curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
            - git clone --depth 1 https://github.com/theodo-group/theodo-scan.git /tmp/theodo-scan
            - export PATH="/tmp/theodo-scan/bin:$PATH"
            - theodo-scan run
```

`atlassian/default-image:4` already ships `git` and the AWS CLI v2.

---

## Azure Pipelines

File: `azure-pipelines.yml` (add the job to your existing file)

Azure DevOps does not provide native AWS OIDC. Create an **AWS service connection** (Project settings → Service connections → New → AWS), then reference it from the `AWSShellScript` task. The [AWS Toolkit for Azure DevOps](https://marketplace.visualstudio.com/items?itemName=AmazonWebServices.aws-vsts-tools) extension must be installed on the organization.

```yaml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: ubuntu-latest

steps:
  - checkout: self

  - task: AWSShellScript@1
    displayName: Run theodo-scan
    inputs:
      awsCredentials: '<aws-service-connection>'
      regionName: '<AWS_REGION>'
      scriptType: 'inline'
      inlineScript: |
        set -e
        sudo apt-get update && sudo apt-get install -y --no-install-recommends jq
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
        git clone --depth 1 https://github.com/theodo-group/theodo-scan.git "$HOME/theodo-scan"
        export PATH="$HOME/theodo-scan/bin:$PATH"
        theodo-scan run
```

`AWSShellScript` injects the service connection's credentials as standard AWS environment variables for the script's lifetime.
