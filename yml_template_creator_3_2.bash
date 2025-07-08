#!/bin/bash

# Generates a YAML annotation block from a list of modules, based on mapping.
# Inject it into a Flank config template as annotation target.

input_file="$1"
output_file="output_flank.yml"
template_file="flank.yml"
map_file="module_map.txt"

map_module() {
    local module="$1"
    local annotation="com.default.module"

    if [ -f "$map_file" ]; then
        local mapped
        mapped=$(grep -E "^$module=" "$map_file" | head -n1 | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [ -n "$mapped" ]; then
            annotation="$mapped"
        else
            # To prevent PR from failing if no mapping found (e.g. module was changed -  added / removed / renamed) and add standard annotation for PR tests.
            # We need to make some notification mechanism in the future.
            echo "No mapping found for module '$module'. Adding default - $annotation." >&2
        fi
    fi

    echo "$annotation"
}

# Deduplication tracker
duplicate=""
# Modules list block for YAML
modules_list=""

while IFS= read -r module || [ -n "$module" ]; do
    # Trim leading/trailing whitespace
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    # Skip empty lines
    [ -z "$module" ] && continue
    # Get annotation for module
    annotation=$(map_module "$module")
    # Deduplicate: only add if not already seen
    if ! echo "$duplicate" | grep -qx "$annotation"; then
        duplicate="$duplicate
$annotation"
        modules_list="$modules_list
- annotation: $annotation"
    fi
done < "$input_file"

#Format for YAML: remove empty lines and indent each line by 4 spaces
modules_list=$(printf '%s\n' "$modules_list" | sed '/^[[:space:]]*$/d' | sed 's/^/    /')

export target="$modules_list"

# Generate output YAML
envsubst < "$template_file" > "$output_file"

echo "YAML successfully generated: $output_file"
