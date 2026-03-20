#!/usr/bin/env bash
# Script to create branch protection rules in GitHub via REST API.
# Requires: GITHUB_OWNER, GITHUB_REPO, GITHUB_TOKEN environment variables.

set -euo pipefail

GITHUB_OWNER="${GITHUB_OWNER:-}"
GITHUB_REPO="${GITHUB_REPO:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

if [ -z "${GITHUB_OWNER:-}" ] || [ -z "${GITHUB_REPO:-}" ] || [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Please set GITHUB_OWNER, GITHUB_REPO and GITHUB_TOKEN environment variables."
  echo "Example:"
  echo "  export GITHUB_OWNER=ayeme006"
  echo "  export GITHUB_REPO=eShopOnWeb"
  echo "  export GITHUB_TOKEN=uioiuytyuio"
  exit 2
fi

API_URL="https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/branches/main/protection"

echo "Creating branch protection rule for 'main'..."
payload=$(cat <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["build", "tests"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
)

curl -sS \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -X PUT \
  -d "$payload" \
  "$API_URL" 

echo "Branch protection rule for 'main' created successfully!"
echo "Note: Update 'contexts' array to match your actual CI job names."
echo "Run similar rule for 'develop' branch if using feature branch workflow."
