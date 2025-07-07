#!/bin/bash
set -e

changed_files_file="$1"
# Read changed files into an array, one per line
# For Bash 3.2 (no mapfile), use while-read loop:
changed_files=()
while IFS= read -r line || [[ -n "$line" ]]; do
    changed_files+=("$line")
done < "$changed_files_file"

include_files=("settings.gradle")

# Use indexed arrays instead of associative arrays for Bash 3.2 compatibility
module_paths=()
module_names=()

# Regex pattern to match lines like: include ':app' or include ":module:core"
pattern='include[[:space:]]*['"'"'"]([^'"'"']+)['"'"'"]'

echo "Parsing included modules from files: ${include_files[*]}"
for f in "${include_files[@]}"; do
    if [[ -f "$f" ]]; then
        echo "Processing $f"
        while IFS= read -r line || [[ -n "$line" ]]; do
            trimmed_line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            if [[ "$trimmed_line" =~ $pattern ]]; then
                module="${BASH_REMATCH[1]}"
                # Replace colon ':' with slash '/', no backslash before slash here!
                path="${module//:/\/}"
                # Remove leading slash if any
                path="${path#/}"
                module_paths+=("$path")
                module_names+=("$module")
                echo "  Found module: '$module' mapped to path: '$path'"
            fi
        done < "$f"
    else
        echo "Warning: Include file '$f' does not exist."
    fi
done

affected_modules=()

echo "Matching changed files to modules..."

for file in "${changed_files[@]}"; do
    file="${file#./}"  # Normalize leading ./ if present
    echo "  Checking changed file: $file"
    for i in "${!module_paths[@]}"; do
        module_path="${module_paths[$i]}"
        echo "    Against module path: $module_path"
        # Check if file path starts with module path + '/'
        if [[ "$file" == "$module_path/"* ]]; then
            raw="${module_names[$i]}"
            echo "    Matched module name raw: '$raw'"

            # Extract base module name (first segment after colon)
            raw="${raw#:}"  # Remove leading colon
            if [[ "$raw" == *:* ]]; then
                module_name="${raw%%:*}"
            else
                module_name="$raw"
            fi

            echo "    Extracted module name: '$module_name'"

            affected_modules+=("$module_name")
            break
        fi
    done
done

# Output unique affected modules
printf "%s\n" "${affected_modules[@]}" | sort -u > affected-modules.txt

echo "Modules successfully written to affected-modules.txt:"
cat affected-modules.txt
