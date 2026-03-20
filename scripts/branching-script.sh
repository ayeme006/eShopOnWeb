#!/usr/bin/env bash
set -euo pipefail

# --- CONFIGURATION ---
GITHUB_OWNER="${GITHUB_OWNER:-}"
GITHUB_REPO="${GITHUB_REPO:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
API_URL="https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/git/refs"

# Ensure the token exists in the environment
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "Error: GITHUB_TOKEN is not set."
    echo "Please run: export GITHUB_TOKEN=your_token_here"
    exit 1
fi

# Function to create a branch via GitHub API using sed/grep
create_branch() {
    local branch_name=$1
    local source_branch=$2
    
    echo "Creating branch '$branch_name' from '$source_branch'..."
    
    # 1. Get the SHA of the latest commit on the source branch
    # We use grep to find the "sha" line and sed to strip the quotes and commas
    local response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
         "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/git/refs/heads/$source_branch")
    
    # Extract SHA: Look for "sha": "...", then extract the middle part
    local sha=$(echo "$response" | grep '"sha":' | head -n 1 | sed 's/.*"sha": "\(.*\)".*/\1/')

    if [[ -z "$sha" || "$sha" == *"{"* ]]; then
        echo "Error: Could not find SHA for source branch '$source_branch'."
        return 1
    fi

    # 2. Create the new branch pointing to that SHA
    local create_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
         -H "Authorization: Bearer $GITHUB_TOKEN" \
         -H "Accept: application/vnd.github.v3+json" \
         -d "{\"ref\": \"refs/heads/$branch_name\", \"sha\": \"$sha\"}" \
         "$API_URL")

    if [[ "$create_status" == "201" ]]; then
        echo "Successfully created '$branch_name'."
    elif [[ "$create_status" == "422" ]]; then
        echo "Notice: Branch '$branch_name' already exists or naming conflict."
    else
        echo "Failed to create branch. HTTP Status: $create_status"
    fi
}

# --- CREATE THE GITFLOW STRUCTURE ---

# 1. Primary Integration Branch
create_branch "develop" "main"

# 2. Feature Branch Example
create_branch "feature/no-jq-setup" "develop"

# 3. Release Branch Example
create_branch "release/v1.0.0" "develop"

# 4. Hotfix Branch Example
create_branch "hotfix/api-fix" "main"

echo -e "\nAll GitFlow branches processed!"