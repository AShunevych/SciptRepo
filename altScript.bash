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

for file in "${changed_files[@]}"; do
    for module_path in "${!module_map[@]}"; do
        if [[ "$file" == "$module_path/"* ]]; then
            # Return top module name, e.g. app
            affected_modules+=("$(sed -E 's/^:([^:]+).*/\1/' <<< "${module_map[$module_path]}")")
            # Alt variant: returns  middle module name, e.g. app/core 
            # However it will require to add more annotaion generation logic to [produceTestTargtsForModule.bash], but I think top-level is enough 
            # affected_modules+=("$(echo "${module_map[$module_path]}" | sed 's/^://; s/:/\//g')")
            break
        fi
    done
done

# Output unique affected modules
printf "%s\n" "${affected_modules[@]}" | sort -u > affected-modules.txt

echo "Modules successfully written to affected-modules.txt:"
cat affected-modules.txt
