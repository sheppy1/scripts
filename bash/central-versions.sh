#!/bin/bash

# Parse versions from JSON file
json_file="central-versions.json"
required_terraform_version=""
providers=()

# Read required_terraform_version
required_terraform_version=$(jq -r .required_terraform_version "$json_file")

# Iterate through provider versions directly
while IFS="=" read -r key value; do
  key=$(echo "$key" | xargs)
  value=$(echo "$value" | xargs)
  [ -z "$key" ] && continue

  if [[ "$key" == "required_terraform_version" ]]; then
    continue  # Skip required_terraform_version
  fi

  provider_source=$(jq -r ".required_providers[\"$key\"].source" "$json_file")
  provider_version=$(jq -r ".required_providers[\"$key\"].version" "$json_file")

  providers+=("$key=$provider_source:$provider_version")
done < <(jq -r '.required_providers | to_entries[] | "\(.key)=\(.value.source)"' "$json_file")

# Function to generate versions.tf content (modified)
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
    IFS='=' read -r provider_name provider_info <<< "$provider"
    IFS=':' read -r provider_source provider_version <<< "$provider_info"

    cat <<EOF
    $provider_name = {
      source  = "$provider_source"
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
