#!/bin/bash
set -e

changed_files_file="$1"
echo "Reading changed files from: $changed_files_file"
mapfile -t changed_files < "$changed_files_file"
echo "Changed files read:"
printf "  %s\n" "${changed_files[@]}"

include_files=("settings.gradle")
declare -A module_map

Regex pattern to match lines like: include ':app' or include ":module:core"
# '' can cause issues while parsing
pattern='include[[:space:]]*['"'"'"]([^'"'"']+)['"'"'"]'

echo "Parsing included modules from files: ${include_files[*]}"
for f in "${include_files[@]}"; do
    if [[ -f "$f" ]]; then
        echo "Processing $f"
        while IFS= read -r line; do
            trimmed_line="$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
            if [[ "$trimmed_line" =~ $pattern ]]; then
                module="${BASH_REMATCH[1]}"
                path="${module//:/\/}"
                path="${path#/}"
                module_map["$path"]="$module"
                echo "  Found module: '$module' mapped to path: '$path'"
            fi
        done < "$f"
    else
        echo "Warning: Include file '$f' does not exist."
    fi
done

declare -a affected_modules
echo "Matching changed files to modules..."

for file in "${changed_files[@]}"; do
    file="${file#./}"  # Normalize leading ./ if present
    echo "  Checking changed file: $file"
    for module_path in "${!module_map[@]}"; do
        if [[ "$file" == "$module_path/"* ]]; then
            module_name="$(sed -E 's/^:([^:]+).*/\1/' <<< "${module_map[$module_path]}")"
            echo "    File belongs to module path: '$module_path' (module: '$module_name')"
            affected_modules+=("$module_name")
            break
        fi
    done
done

echo "Unique affected modules:"
printf "  %s\n" "${affected_modules[@]}" | sort -u

printf "%s\n" "${affected_modules[@]}" | sort -u > affected-modules.txt

echo "Modules successfully written to affected-modules.txt:"
cat affected-modules.txt
