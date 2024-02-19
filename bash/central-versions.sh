#!/bin/bash

# Parse versions from JSON file
json_file="central-versions.json"
providers=()

# Iterate over JSON keys and extract versions
while IFS="=" read -r key value; do
  # Remove leading and trailing whitespaces
  key=$(echo "$key" | xargs)
  value=$(echo "$value" | xargs)
  
  # Skip empty lines
  [ -z "$key" ] && continue

  # Add provider and version to the array
  providers+=("$key=$value")
done < <(jq -r "to_entries|map(\"\(.key)=\(.value)\")|.[]" "$json_file")

# Function to update versions.tf file
update_versions_file() {
  local file_path="$1"
  
  if [ -f "$file_path" ]; then
    # Update an existing file
    for provider in "${providers[@]}"; do
      IFS='=' read -r provider_name provider_version <<< "$provider"
      # Check if the provider block already exists
      if grep -q "$provider_name" "$file_path"; then
        # Use awk to replace the version within the existing provider block with proper indentation
        awk -v provider_name="$provider_name" -v provider_version="$provider_version" '
          BEGIN { found = 0 }
          /'"$provider_name"'/ { found = 1; print; next }
          found && /version/ { found = 0; print "      version = \"" provider_version "\""; next }
          found { next }
          { print }
        ' "$file_path" > "$file_path.tmp" && mv "$file_path.tmp" "$file_path"
      fi
    done
  fi
}

# Update versions.tf in the root directory
update_versions_file "versions.tf"

# Update versions.tf in the integration_tests/fixtures directory
update_versions_file "integration_tests/fixtures/versions.tf"
