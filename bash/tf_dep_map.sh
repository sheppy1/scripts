#!/bin/bash

find_tf_files() {
    find "$1" -type d -name 'integration_test' -prune -o -type f -name "*.tf" -print
}

parse_tf_file() {
    local file="$1"
    local current_module
    current_module=$(basename "$(dirname "$file")")
    grep -oP '(module|data)\s+"\K[^"]+' "$file" | while read -r resource_type module_name; do
        echo "$current_module -> $module_name ($resource_type)"
    done
}

create_dependency_map() {
    local directory="$1"
    declare -A module_dependencies

    while IFS= read -r tf_file; do
        while IFS= read -r dependency; do
            module=$(echo "$dependency" | awk '{print $1}')
            dependent=$(echo "$dependency" | awk '{print $3}')
            type=$(echo "$dependency" | awk '{print $5}')
            module_dependencies["$module"]+="$dependent ($type) "
        done < <(parse_tf_file "$tf_file")
    done < <(find_tf_files "$directory")

    echo "Dependency Map:"
    for module in "${!module_dependencies[@]}"; do
        echo "$module depends on ${module_dependencies[$module]}"
    done
}

terraform_directory="./terraform_configs" 

create_dependency_map "$terraform_directory"
