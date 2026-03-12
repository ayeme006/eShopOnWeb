# GitHub Setup Guide for eShopOnWeb

## 1. Branch Protection Rules

### Prerequisites
- You must be a repository owner or have admin permissions

### Apply branch protection for `main` and `develop`

1. Go to **Settings** → **Branches**
2. Click **Add rule** for `main`:
   - Pattern: `main`
   - ✅ Require a pull request before merging
   - ✅ Require approvals (1 approvals)
   - ✅ Dismiss stale pull request approvals when new commits are pushed
   - ✅ Require review from Code Owners
   - ✅ Require status checks to pass before merging (strict)
      - Status checks: `build`, `tests`
   - ✅ Require branches to be up to date before merging
   - ✅ Require linear history
   - ✅ Restrict who can push to matching branches (optional)
   - ❌ Allow force pushes
   - ❌ Allow deletions

3. Repeat for `develop` with the same rules (but require 1-2 approvals instead of 2 if preferred)

### Automation

Run the provided script to apply rules via API:

```bash
export GITHUB_OWNER=<your-githubusername-or-org>
export GITHUB_REPO=eShopOnWeb
export GITHUB_TOKEN=<your-personal-access-token>

bash scripts/set-github-branch-policies.sh
```

> Token must have `repo` and `admin:repo_hook` scopes.

---

## 2. Required Secrets

Add these to **Settings** → **Secrets and variables** → **Actions**:

| Secret | Description |
|--------|-------------|
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_CLIENT_ID` | Service principal client ID (from federated credential setup) |
| `SONAR_TOKEN` | SonarCloud organizational token |

---

## 3. OIDC Federated Credentials (for Azure login)

Enable workload identity federation to avoid storing secrets in GitHub:

```bash
az app registration create --display-name "eShopOnWeb-GitHub-Actions"
az app registration federated-credential create \
  --id <client-id> \
  --parameters '{
    "name": "eShopOnWeb-GitHub",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<owner>/<repo>:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

---

## 4. Environments and Approvals

Define deployment protection rules:

1. Go to **Settings** → **Environments** → **New environment**
2. Create: `development`, `staging`, `production`
3. For `staging` and `production`, enable **Required reviewers**:
   - Set specific users or teams who must approve deployments

---

## 5. (Optional) Dependabot Alerts

Enable automated dependency scanning:

1. Go to **Settings** → **Security & analysis**
2. Enable:
   - ✅ Dependabot alerts
   - ✅ Dependabot security updates
   - ✅ Dependency graph

---

## 6. (Optional) Code Security & Analysis

Enable GitHub Advanced Security (if available on your plan):

1. Go to **Settings** → **Security & analysis**
2. Enable:
   - ✅ CodeQL analysis
   - ✅ Secret scanning
   - ✅ Secret scanning push protection

---

## 7. Run CI/CD Workflows

Workflows are triggered automatically on:
- **CI (`ci-docker.yml`)**: Pushes to `develop` and PRs to `main`
- **CD (`cd-docker.yml`)**: Pushes to `main` (dev → staging → prod)

Monitor at **Actions** tab in your repository.

---

## 8. Code Review with CODEOWNERS

The `CODEOWNERS` file at the repository root automatically requests reviews from designated teams/users:

```
src/ApplicationCore/    @yourorg/core-team
src/Infrastructure/     @yourorg/infra-team
infra/                  @yourorg/cloud-team
.github/workflows/      @yourorg/devops-team
```

Edit as needed and commit to the repository.

---

## Troubleshooting

### Workflow fails on Azure login
- Verify `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` are set correctly.
- Ensure the service principal has the required roles in the Azure subscription.
- Verify the federated credential issuer matches `https://token.actions.githubusercontent.com`.

### Branch protection blocks merges
- Check that all required status checks (CI job names) are passing.
- Ensure PR has 2 approvals (or configured count).
- Check that Code Owners have approved the PR.

### Secrets not available in workflow
- Verify the secret is set in the environment (if using environment-level secrets).
- Ensure the workflow has permissions: `contents: read`, `id-token: write`.
