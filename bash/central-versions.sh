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

    # Check if the provider is present in the original versions.tf
    if grep -q "$provider_name" "versions.tf"; then
      cat <<EOF
    $provider_name = {
      source  = "$provider_source"
      version = "$provider_version"
    }
EOF
    fi
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

# Handle the cloud block for integration_tests/fixtures
if grep -q "cloud {" "integration_tests/fixtures/versions.tf"; then
  # Extract only the cloud block and save it to tfcloud-config.tf
  awk '/^  cloud {/,/^  }$/' "integration_tests/fixtures/versions.tf" > "integration_tests/fixtures/tfcloud-config.tf"
  # Remove the cloud block from the original versions.tf
  awk '!/^  cloud {/,/^  }$/' "integration_tests/fixtures/versions.tf" > "integration_tests/fixtures/versions.tmp" && mv "integration_tests/fixtures/versions.tmp" "integration_tests/fixtures/versions.tf"
  # Wrap the cloud block in a terraform block
  echo -e "terraform {" > "integration_tests/fixtures/tfcloud-config.tmp"
  cat "integration_tests/fixtures/tfcloud-config.tf" >> "integration_tests/fixtures/tfcloud-config.tmp"
  echo -e "}\n" >> "integration_tests/fixtures/tfcloud-config.tmp"
  mv "integration_tests/fixtures/tfcloud-config.tmp" "integration_tests/fixtures/tfcloud-config.tf"
fi

# Save to versions.tf in the integration_tests/fixtures directory
echo "$versions_tf_content" > "integration_tests/fixtures/versions.tf"
