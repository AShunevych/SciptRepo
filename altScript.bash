#!/bin/bash
set -e

# Get list of files changed between current HEAD and origin/master
changed_files=($(git diff --name-only origin/master...HEAD))

# Files that may contain module includes (like settings.gradle)
include_files=("settings.gradle")

# Declare associative array to store module name -> path mapping
declare -A module_map

# Regex pattern to match lines like: include ':app' or include ":module:core"
# '' can cause issues while parsing
pattern='include[[:space:]]*['"'"'"]([^'"'"']+)['"'"'"]'

# Read each include file and extract included modules
for f in "${include_files[@]}"; do
    if [[ -f "$f" ]]; then
        while IFS= read -r line; do
            # Trim leading and trailing whitespace
            trimmed_line="$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

            # If line matches the include pattern, extract the module name
            if [[ "$trimmed_line" =~ $pattern ]]; then
                module="${BASH_REMATCH[1]}"
                # Convert Gradle path format (for example :app:core) to directory path (app/core)
                path="${module//:/\/}"
                path="${path#/}"  # Remove leading slash if present
                module_map["$path"]="$module"
            fi
        done < "$f"
    fi
done

# Sort module paths by descending length to prioritize deeper modules first
# This can be an option if needed, but first or mid level modules is enough,
# I don't see any sense to run tests only to some third level like (app:core:core2), when we can simply test entire module (app:core)
#
#sorted_module_paths=($(for path in "${!module_map[@]}"; do
#    echo "$path"
#done | awk '{ print length, $0 }' | sort -rn | cut -d" " -f2-))
#

# Determine affected modules by matching changed files against sorted paths
for file in "${changed_files[@]}"; do
    for module_path in "${!module_map[@]}"; do
        if [[ "$file" == "$module_path/"* ]]; then
            affected_modules+=("$(echo "${module_map[$module_path]}" | sed 's/^://; s/:/\//g')")
            break
        fi
    done
done

# Output unique affected modules
printf "%s\n" "${affected_modules[@]}" | sort -u > affected-modules.txt

echo "Modules successfully written to affected-modules.txt:"
cat affected-modules.txt