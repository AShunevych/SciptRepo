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
            echo "No mapping found for module '$module'. Adding default - $annotation." >&2
        fi
    fi

    echo "$annotation"
}

# Tracker for deduplication
duplicate=""
annotations=""

while IFS= read -r module || [ -n "$module" ]; do
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$module" ] && continue

    annotation=$(map_module "$module")

    # Deduplicate using a newline-separated string
    if ! echo "$duplicate" | grep -xq "$annotation"; then
        duplicate="${duplicate}
$annotation"

        # Append to annotations string with comma separator
        if [ -z "$annotations" ]; then
            annotations="$annotation"
        else
            annotations="${annotations}, $annotation"
        fi
    fi
done < "$input_file"

# Prepare YAML block with a single annotation line
modules_list=" - annotation: $annotations"

export target="$modules_list"

# Generate output YAML
envsubst < "$template_file" > "$output_file"

echo "YAML successfully generated: $output_file"
