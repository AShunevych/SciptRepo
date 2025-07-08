#!/bin/bash

input_file="$1"
output_file="output_flank.yml"
template_file="flank.yml"
map_file="module_map.txt"

# Function to map module name to YAML annotation
map_module() {
    local module="$1"
    local annotation="com.default.module"
    local mapped

    if [ -f "$map_file" ]; then
        mapped=$(grep -E "^$module=" "$map_file" | head -n1 | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$mapped" ]; then
            annotation="$mapped"
        else
            echo "WARNING: No mapping for module '$module'. Using default." >&2
        fi
    else
        echo "WARNING: Map file '$map_file' not found. Using default for all modules." >&2
    fi

    echo "$annotation"
}

# Track seen annotations to avoid duplicates
seen_annotations=""

# Build list of YAML entries
modules_list=""
while IFS= read -r module || [ -n "$module" ]; do
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') # Trim whitespace
    [ -z "$module" ] && continue  # Skip empty lines

    annotation=$(map_module "$module")

    # Check if this annotation has already been added
    if ! echo "$seen_annotations" | grep -qx "$annotation"; then
        seen_annotations="$seen_annotations
$annotation"
        modules_list="$modules_list
- annotation: $annotation"
    fi
done < "$input_file"

# Remove leading/trailing blank lines and indent by 4 spaces
modules_list=$(printf '%s\n' "$modules_list" | sed '/^[[:space:]]*$/d' | sed 's/^/    /')

# Debug output
echo "DEBUG: Final modules list:"
echo "$modules_list"
echo "------"

# Export for envsubst
export target="$modules_list"

# Generate final YAML
envsubst < "$template_file" > "$output_file"

echo "YAML was generated"
