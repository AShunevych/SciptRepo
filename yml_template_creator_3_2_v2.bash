#!/bin/bash

input_file="$1"               # File with module names, e.g. input_modules.txt
output_file="output_flank.yml"
template_file="flank.yml"
map_file="module_map.txt"

map_module() {
    local module="$1"
    if [ -f "$map_file" ]; then
        grep -E "^$module=" "$map_file" | head -n1 | cut -d'=' -f2- | \
            sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    fi
}

seen=""
targets=""
first_entry=true

while IFS= read -r module || [ -n "$module" ]; do
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$module" ] && continue

    mapped=$(map_module "$module")
    [ -z "$mapped" ] && continue

    if [ "$module" = "app" ]; then
        targets="    - annotation $mapped"
        first_entry=false
        break
    fi

    echo "$seen" | grep -Fqx "$mapped" && continue
    seen="$seen
$mapped"

    IFS=',' 
    for test in $mapped; do
        test=$(echo "$test" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ "$first_entry" = true ]; then
            targets="    - class $test"
            first_entry=false
        else
            targets="${targets}
    - class $test"
        fi
    done
    unset IFS
done < "$input_file"

testShardsNumber=0
count=$(echo "$targets" | grep -o 'class' | wc -l)
if [[ "$targets" == *annotation* ]] || [ "$count" -gt 16 ]; then
    testShardsNumber=8
else
    testShardsNumber=2
fi

# Escape double quotes but keep real newlines intact
escaped_targets=$(printf '%s\n' "$targets" | sed 's/"/\\"/g')

# Preserving multi-line targets properly in case if targets are long
awk -v t="$escaped_targets" -v s="$testShardsNumber" '
  $0 ~ /\$target/ {
    n = split(t, lines, "\n")
    for (i = 1; i <= n; i++) print lines[i]
    next
  }
  {
    gsub(/\$testShardsNumber/, s)
    print
  }
' "$template_file" > "$output_file"

echo "✅ YAML successfully generated: $output_file"
