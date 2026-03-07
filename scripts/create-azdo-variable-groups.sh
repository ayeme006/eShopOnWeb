#!/usr/bin/env bash
# Script to create variable groups in Azure DevOps that link to Key Vault
# Requires: AZDO_ORG_URL, AZDO_PROJECT, AZDO_PAT environment variables
# Note: Uses only bash/grep/cut (no jq required)

set -euo pipefail

if [ -z "${AZDO_ORG_URL:-}" ] || [ -z "${AZDO_PROJECT:-}" ] || [ -z "${AZDO_PAT:-}" ]; then
  echo "Please set AZDO_ORG_URL, AZDO_PROJECT and AZDO_PAT environment variables."
  echo "Example:"
  echo "  export AZDO_ORG_URL=https://dev.azure.com/yourOrg"
  echo "  export AZDO_PROJECT=eShopOnWeb"
  echo "  export AZDO_PAT=your-personal-access-token"
  exit 2
fi

VAULT_NAME="${1:-eshoponwebkv}"
VAULT_RESOURCE_GROUP="${2:-Eshop-wus-rg}"
SUBSCRIPTION_ID="${3:-24e9df87-f699-49ca-ad4e-eaf026d4fbf8}"
SERVICE_CONNECTION_NAME="${4:-Tema-sc}"

API_URL="$AZDO_ORG_URL/$AZDO_PROJECT/_apis/distributedtask/variablegroups"
ENDPOINTS_API_URL="$AZDO_ORG_URL/$AZDO_PROJECT/_apis/serviceendpoint/endpoints"

# Fetch service connection ID
echo "Fetching service connection ID for '$SERVICE_CONNECTION_NAME'..."
if base64 --help 2>&1 | grep -q -- '-w'; then
  ENDPOINTS_AUTH="Basic $(echo -n ":$AZDO_PAT" | base64 -w 0)"
else
  ENDPOINTS_AUTH="Basic $(echo -n ":$AZDO_PAT" | base64 | tr -d '\n')"
fi

endpoints_response=$(curl -sS \
  -H "Authorization: $ENDPOINTS_AUTH" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  "$ENDPOINTS_API_URL?api-version=6.0-preview.1")

if echo "$endpoints_response" | grep -q "\"value\":\[\]"; then
  echo "✗ No service connections found in the project."
  exit 1
fi

SERVICE_CONNECTION_ID=$(echo "$endpoints_response" | grep -B10 "\"name\":" | grep -oE '"id":"[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}"' | head -1 | cut -d'"' -f4)

LAST_REFRESHED=$(date -u +'%Y-%m-%dT%H:%M:%S.000Z' 2>/dev/null || echo "2026-03-06T00:00:00.000Z")

echo "DEBUG: Full endpoints response:"
echo "$endpoints_response" | head -c 500
echo ""
echo ""

if [ -z "$SERVICE_CONNECTION_ID" ] || [ "$SERVICE_CONNECTION_ID" = "null" ]; then
  echo "✗ Could not find service connection '$SERVICE_CONNECTION_NAME'."
  echo "Available service connections:"
  echo "$endpoints_response" | grep -o '"name":"[^"]*"' || echo "  (none found)"
  exit 1
fi

echo "✔ Found service connection ID: $SERVICE_CONNECTION_ID"

# Create Basic Auth header (base64 encoded :PAT)
# some systems' base64 uses different flags, fall back if -w not available
if base64 --help 2>&1 | grep -q -- '-w'; then
  AUTH_HEADER="Basic $(echo -n ":$AZDO_PAT" | base64 -w 0)"
else
  AUTH_HEADER="Basic $(echo -n ":$AZDO_PAT" | base64 | tr -d '\n')"
fi

echo "Creating Variable Group 'Common-Secrets' linked to Key Vault '$VAULT_NAME'..."
echo "API URL: $API_URL"
echo ""

payload=$(cat <<EOF
{
  "name": "Common-Secrets",
  "description": "Secrets from Key Vault linked to eShopOnWeb",
  "type": "AzureKeyVault",
  "providerData": {
    "vault": "$VAULT_NAME",
    "resourceGroup": "$VAULT_RESOURCE_GROUP",
    "subscriptionId": "$SUBSCRIPTION_ID",
    "serviceEndpointId": "$SERVICE_CONNECTION_ID",
    "lastRefreshedOn": "$LAST_REFRESHED"
  },
  "isShared": true,
  "variables": {
    "__placeholder": { "value": "true", "isSecret": false }
  }
}
EOF
)

# POST Common-Secrets with status capture
tmp=$(curl -sS -w "\n%{http_code}" \
  -H "Authorization: $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d "$payload" \
  "$API_URL?api-version=6.0-preview.1")

http_status=$(echo "$tmp" | tail -n1)
response=$(echo "$tmp" | sed '$d')

echo "HTTP status: $http_status"
echo "Response:"
echo "$response"
echo ""

if [ "$http_status" -ge 400 ]; then
  if [ "$http_status" -eq 401 ] || [ "$http_status" -eq 403 ] || [ "$http_status" -eq 302 ]; then
    echo "✗ Authentication failed or insufficient PAT scopes."
    echo "  1. AZDO_ORG_URL is correct (e.g., https://dev.azure.com/yourOrg)"
    echo "  2. AZDO_PROJECT is correct"
    echo "  3. AZDO_PAT is valid and has 'Variable Groups' read/write permissions"
    echo "  4. PAT has not expired"
  else
    echo "✗ Request failed with status $http_status. See response above."
  fi
  exit 1
fi

GROUP_ID=$(echo "$response" | grep -o '"id":[0-9]*' | cut -d':' -f2 | head -1)

if [ -n "$GROUP_ID" ] && [ "$GROUP_ID" != "null" ]; then
  echo "✓ Variable Group 'Common-Secrets' created with ID: $GROUP_ID"
  echo ""
  echo "Next steps:"
  echo "1. Go to Pipelines → Library → Variable groups in Azure DevOps"
  echo "2. Select 'Common-Secrets' and authorize it to use in all pipelines"
  echo "3. Add individual secrets from Key Vault (they will be fetched dynamically)"
  echo ""
  echo "In your pipeline YAML, reference it with:"
  echo "  variables:"
  echo "  - group: Common-Secrets"
else
  echo "✗ Failed to create variable group. Check response above for details."
  exit 1
fi

echo ""
echo "Creating Variable Group 'Build-Config' for non-secret pipeline variables..."

build_config_payload=$(cat <<'PAYLOAD'
{
  "name": "Build-Config",
  "description": "Build configuration variables (non-secrets)",
  "type": "Vsts",
  "isShared": true,
  "variables": {
    "DOTNET_VERSION": {
      "value": "8.0.x",
      "isSecret": false
    },
    "SONARCLOUD_ORG": {
      "value": "your-org",
      "isSecret": false
    },
    "REGISTRY": {
      "value": "eshoponwebacr",
      "isSecret": false
    },
    "IMAGE_REPO": {
      "value": "eshoponweb/web",
      "isSecret": false
    },
    "ACR_REGISTRY_NAME": {
      "value": "eshoponwebacr",
      "isSecret": false
    }
  }
}
PAYLOAD
)

http_status_and_body=$(curl -sS -w "\n%{http_code}" \
  -H "Authorization: $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d "$build_config_payload" \
  "$API_URL?api-version=6.0-preview.1")

http_status=$(echo "$http_status_and_body" | tail -n1)
response=$(echo "$http_status_and_body" | sed '$d')

echo "HTTP status for Build-Config: $http_status"
echo "Response body:"
echo "$response"
echo ""

if [ "$http_status" -ge 400 ]; then
  echo "✗ Build-Config request failed with $http_status. Check PAT scopes."
  exit 1
fi

BUILD_GROUP_ID=$(echo "$response" | grep -o '"id":[0-9]*' | cut -d':' -f2 | head -1)

if [ -n "$BUILD_GROUP_ID" ] && [ "$BUILD_GROUP_ID" != "null" ]; then
  echo "✓ Variable Group 'Build-Config' created with ID: $BUILD_GROUP_ID"
else
  echo "✗ Failed to create Build-Config variable group."
  exit 1
fi

echo ""
echo "Creating Variable Group 'Deployment-Config' for environment-specific variables..."

deploy_payload=$(cat <<'PAYLOAD'
{
  "name": "Deployment-Config",
  "description": "Deployment configuration variables",
  "type": "Vsts",
  "isShared": true,
  "variables": {
    "AZURE_SERVICE_CONNECTION": {
      "value": "Tema-sc",
      "isSecret": false
    },
    "SUBSCRIPTION_ID": {
      "value": "24e9df87-f699-49ca-ad4e-eaf026d4fbf8",
      "isSecret": false
    },
    "RESOURCE_GROUP": {
      "value": "Eshop-wus-rg",
      "isSecret": false
    },
    "LOCATION": {
      "value": "westus",
      "isSecret": false
    },
    "VAULT_NAME": {
      "value": "kv-eshop-270674242",
      "isSecret": false
    }
  }
}
PAYLOAD
)

http_status_and_body=$(curl -sS -w "\n%{http_code}" \
  -H "Authorization: $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d "$deploy_payload" \
  "$API_URL?api-version=6.0-preview.1")

http_status=$(echo "$http_status_and_body" | tail -n1)
response=$(echo "$http_status_and_body" | sed '$d')

echo "HTTP status for Deployment-Config: $http_status"
echo "Response body:"
echo "$response"
echo ""

if [ "$http_status" -ge 400 ]; then
  echo "✗ Deployment-Config request failed with $http_status. Check PAT scopes."
  exit 1
fi

DEPLOY_GROUP_ID=$(echo "$response" | grep -o '"id":[0-9]*' | cut -d':' -f2 | head -1)

if [ -n "$DEPLOY_GROUP_ID" ] && [ "$DEPLOY_GROUP_ID" != "null" ]; then
  echo "✓ Variable Group 'Deployment-Config' created with ID: $DEPLOY_GROUP_ID"
else
  echo "✗ Failed to create Deployment-Config variable group."
  exit 1
fi

echo ""
echo "✓ All variable groups created successfully!"
