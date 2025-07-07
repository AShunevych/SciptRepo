#!/bin/bash
set -e

changed_files_file="$1"

# Read changed files into array
changed_files=()
while IFS= read -r line; do
    changed_files+=("$line")
done < "$changed_files_file"

include_files=("settings.gradle")
module_paths=()
module_names=()

# Pattern to match: include ':app' or include ":module:core"
pattern='include[[:space:]]*['"'"'"]([^'"'"']+)['"'"'"]'

# Extract module includes
for f in "${include_files[@]}"; do
    if [[ -f "$f" ]]; then
        while IFS= read -r line; do
            trimmed_line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            if [[ "$trimmed_line" =~ $pattern ]]; then
                module="${BASH_REMATCH[1]}"
                path="${module//:/\/}"
                path="${path#/}"
                module_paths+=("$path")
                module_names+=("$module")
            fi
        done < "$f"
    fi
done

# Track affected modules
affected_modules=()

# Match changed files to modules
for file in "${changed_files[@]}"; do
    file="${file#./}"  # Normalize
    for i in "${!module_paths[@]}"; do
        module_path="${module_paths[$i]}"
        echo "Checking module path: $module_path"
        if [[ "$file" == "$module_path/"* ]]; then
            raw="${module_names[$i]}"
            echo "module_names[$i]: '$raw'"

            raw="${raw#:}"  # Remove leading colon
            if [[ "$raw" == *:* ]]; then
                module_name="${raw%%:*}"
            else
                module_name="$raw"
            fi

            echo "Extracted module_name: '$module_name'"

            affected_modules+=("$module_name")
            break
        fi
    done
done


# Output unique affected modules
printf "%s\n" "${affected_modules[@]}" | sort -u > affected-modules.txt

echo "Modules successfully written to affected-modules.txt:"
cat affected-modules.txt
