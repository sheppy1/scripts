#!/bin/bash

root_versions_tf=versions.tf
integration_tests_versions_tf=integration_tests/fixtures/versions.tf

# Function to check if the provider is present in the versions.tf file
check_versions_tf() {
  local provider_name="$1"
  local versions_tf_path="$2"

  grep -q "$provider_name" "$versions_tf_path"
}

# Function to generate versions.tf content for a specific file
generate_versions_tf_file() {
  local required_version="$1"
  local json_file="$2"
  local versions_tf_file="$3"

  local providers=()

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
  cat <<EOF
terraform {
  required_version = "$required_version"

  required_providers {
EOF

  for provider in "${providers[@]}"; do
    IFS='=' read -r provider_name provider_info <<< "$provider"
    IFS=':' read -r provider_source provider_version <<< "$provider_info"

    # Check if the provider is present in the original versions.tf
    if check_versions_tf "$provider_name" "$versions_tf_file"; then
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

# Parse versions from JSON file
json_file="central-versions.json"
required_terraform_version=$(jq -r .required_terraform_version "$json_file")

# Handle the cloud block for integration_tests/fixtures
if grep -q "cloud {" "$integration_tests_versions_tf"; then
  # Extract only the cloud block and save it to tfcloud-config.tf
  awk '/^  cloud {/,/^  }$/' "$integration_tests_versions_tf" > "integration_tests/fixtures/tfcloud-config.tf"
  # Remove the cloud block from the original versions.tf
  awk '!/^  cloud {/,/^  }$/' "$integration_tests_versions_tf" > "integration_tests/fixtures/versions.tmp" && mv "integration_tests/fixtures/versions.tmp" "integration_tests/fixtures/versions.tf"
  # Wrap the cloud block in a terraform block
  echo -e "terraform {" > "integration_tests/fixtures/tfcloud-config.tmp"
  cat "integration_tests/fixtures/tfcloud-config.tf" >> "integration_tests/fixtures/tfcloud-config.tmp"
  echo -e "}\n" >> "integration_tests/fixtures/tfcloud-config.tmp"
  mv "integration_tests/fixtures/tfcloud-config.tmp" "integration_tests/fixtures/tfcloud-config.tf"
fi

# Process root versions.tf
generate_versions_tf_file "$required_terraform_version" "$json_file" "$root_versions_tf" > "versions_processed.tf" && mv "versions_processed.tf" "$root_versions_tf"

# Process integration_tests/fixtures/versions.tf
generate_versions_tf_file "$required_terraform_version" "$json_file" "$integration_tests_versions_tf" > "integration_tests/fixtures/versions_processed.tf" && mv "integration_tests/fixtures/versions_processed.tf" "$integration_tests_versions_tf"
