#!/bin/bash

# Parse versions from JSON file
json_file="central-versions.json"
required_terraform_version=""
providers=()

# Read required_terraform_version
required_terraform_version=$(jq -r .required_terraform_version "$json_file")

# Read provider versions
while IFS="=" read -r key value; do
  key=$(echo "$key" | xargs)
  value=$(echo "$value" | xargs)
  [ -z "$key" ] && continue
  providers+=("$key=$value")
done < <(jq -r '. | to_entries[] | "\(.key)=\(.value)"' "$json_file")

# Function to generate versions.tf content
generate_versions_tf() {
  local required_version="$1"
  shift
  local provider_versions=("$@")

  cat <<EOF
terraform {
  required_version = "$required_version"

  required_providers {
EOF

  for provider in "${provider_versions[@]}"; do
    IFS='=' read -r provider_name provider_version <<< "$provider"
    # Skip required_terraform_version
    [ "$provider_name" == "required_terraform_version" ] && continue
    cat <<EOF
    $provider_name = {
      source  = "hashicorp/$provider_name"
      version = "$provider_version"
    }
EOF
  done

  cat <<EOF
  }
}
EOF
}

# Generate versions.tf content
versions_tf_content=$(generate_versions_tf "$required_terraform_version" "${providers[@]}")

# Save to versions.tf in the root directory
echo "$versions_tf_content" > "versions.tf"

# Save to versions.tf in the integration_tests/fixtures directory
echo "$versions_tf_content" > "integration_tests/fixtures/versions.tf"
