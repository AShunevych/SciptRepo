#!/bin/bash
set -e

changed_files_file="$1"
changed_files=()

# Read changed files into an array (Bash 3.2 doesn't support mapfile)
while IFS= read -r line; do
    changed_files+=("$line")
done < "$changed_files_file"

include_files=("settings.gradle")
declare -A module_map

# Regex pattern to match: include ':app' or include ":module:core"
pattern='include[[:space:]]*['"'"'"]([^'"'"']+)['"'"'"]'

# Parse included modules from settings.gradle
for f in "${include_files[@]}"; do
    if [[ -f "$f" ]]; then
        while IFS= read -r line; do
            # Trim leading/trailing whitespace
            trimmed_line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            if [[ "$trimmed_line" =~ $pattern ]]; then
                module="${BASH_REMATCH[1]}"
                path="${module//:/\/}"
                path="${path#/}"
                module_map["$path"]="$module"
            fi
        done < "$f"
    fi
done

affected_modules=()

# Match changed files to modules
for file in "${changed_files[@]}"; do
    file="${file#./}"  # Normalize leading ./ if present
    for module_path in "${!module_map[@]}"; do
        if [[ "$file" == "$module_path/"* ]]; then
            module="${module_map[$module_path]}"
            # Extract first-level module name (e.g., ':app:core' => 'app')
            module_name=$(echo "$module" | sed -E 's/^:([^:]+).*/\1/')
            affected_modules+=("$module_name")
            break
        fi
    done
done

# Output unique affected modules
printf "%s\n" "${affected_modules[@]}" | sort -u > affected-modules.txt

echo "Modules successfully written to affected-modules.txt:"
cat affected-modules.txt
