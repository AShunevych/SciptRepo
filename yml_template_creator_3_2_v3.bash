#!/bin/bash
set -euo pipefail

input_file="$1"
output_file="output_flank.yml"
template_file="flank.yml"
map_file="module_map.json"

# Verify required files exist before processing
[ -f "$input_file" ] || { echo "Missing input file: $input_file"; exit 1; }
[ -f "$map_file" ] || { echo "Missing JSON map: $map_file"; exit 1; }
[ -f "$template_file" ] || { echo "Missing template: $template_file"; exit 1; }

# Function to generate final YAML by replacing placeholders in the template
write_output() {
  local targets="$1"
  local testShardsNumber="$2"
  {
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ "$line" == *"\$target"* ]]; then
        echo "$targets"
      else
        echo "${line//\$testShardsNumber/$testShardsNumber}"
      fi
    done < "$template_file"
  } > "$output_file"
}

seen=""
targets=""
first_entry=true

# Read each module name from the input file
while IFS= read -r module || [ -n "$module" ]; do
    # Trim whitespace
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$module" ] && continue

    echo "🔍 Processing module: '$module'"

    # Special case: if module is 'app', output only its annotation and exit
    if [ "$module" = "app" ]; then
        annotation=$(jq -r --arg mod "$module" '
          .[] | select(.module == $mod) | .tests[0]?' "$map_file")

        targets="    - annotation $annotation"
        write_output "$targets" 8
        echo "Final target is: $targets"
        exit 0
    fi

    # Avoid processing duplicate modules
    echo "$seen" | grep -Fqx "$module" && continue
    seen="$seen
$module"

    # Extract tests array for current module from JSON map
    tests=$(jq -r --arg mod "$module" '
      .[] | select(.module == $mod) | .tests[]?' "$map_file")

    # Append each test as a '- class test_name' entry in targets string
    while IFS= read -r test; do
        [ -z "$test" ] && continue
        if [ "$first_entry" = true ]; then
            targets="    - class $test"
            first_entry=false
        else
            targets="${targets}
    - class $test"
        fi
    done <<< "$tests"
done < "$input_file"

# Decide on number of shards based on number of tests or presence of annotation
count=$(echo "$targets" | grep -c 'class' || true)
if [[ "$targets" == *annotation* ]] || [ "$count" -gt 16 ]; then
    testShardsNumber=8
else
    testShardsNumber=2
fi

echo "--- Final targets ---"
echo "$targets"

write_output "$targets" "$testShardsNumber"

echo "YAML successfully generated: $output_file"
