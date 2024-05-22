#!/bin/bash

# Function to find all *.tf files recursively, excluding 'integration_test' directories
find_tf_files() {
    find "$1" -type d -name 'integration_test' -prune -o -type f -name "*.tf" -print
}

# Function to parse module dependencies in a *.tf file
parse_tf_file() {
    local file="$1"
    local current_module
    current_module=$(basename "$(dirname "$file")")
    grep -oP 'module\s+"\K[^"]+' "$file" | while read -r module; do
        echo "$current_module -> $module"
    done
}

# Main function to create the dependency map for all modules in the given directory
create_dependency_map() {
    local directory="$1"
    declare -A module_dependencies

    while IFS= read -r tf_file; do
        while IFS= read -r dependency; do
            module=$(echo "$dependency" | awk '{print $1}')
            dependent_module=$(echo "$dependency" | awk '{print $3}')
            module_dependencies["$module"]+="$dependent_module "
        done < <(parse_tf_file "$tf_file")
    done < <(find_tf_files "$directory")

    echo "Dependency Map:"
    for module in "${!module_dependencies[@]}"; do
        echo "$module depends on ${module_dependencies[$module]}"
    done
}

# Directory containing the Terraform configurations
terraform_directory="./terraform_configs"  # Change this to your Terraform directory

create_dependency_map "$terraform_directory"
