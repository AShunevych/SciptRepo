#!/bin/bash

input_file="$1"
output_file="output_flank.yml"
template_file="flank.yml"

# Associative array for module -> annotation
declare -A module_annotation_map=(
    [:app]="com.default.module"
    [:core]="com.core.module"
)

# Function to map module name to YAML annotation
map_module() {
    local module="$1"
    local annotation="${module_annotation_map[$module]:-com.default.module}"
    echo "- annotation: $annotation"
}

modules_list=""

# Read module names and generate annotation lines
while IFS= read -r line || [ -n "$line" ]; do
    modules_list="$modules_list
$(map_module "$line")"
done < "$input_file"

# Format step: we should make sure that our output text has proper indentation and readable by flank. Adding 4 indentation for each new line.
modules_list=$(printf '%s' "$modules_list" | sed '/^[[:space:]]*$/d' | sed 's/^/    /')

# print modules_list
echo "DEBUG: Modules list is:"
echo "$modules_list"
echo "------"

# export after trimming
export target="$modules_list"

# Use envsubs to replace paramets in outputed file
envsubst < "$template_file" > "$output_file"

echo "YAML generated "
