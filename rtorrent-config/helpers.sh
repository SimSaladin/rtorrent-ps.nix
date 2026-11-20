#!/usr/bin/env bash

listImports () {
    if [[ $# -gt 0 ]]; then
        printf '%s\n' "$@"
        mapfile -t res < <(sed -n \
                '/^import\s*=/{s/^import\s*=\s*"\?//; s/"\?\s*$// ;p}' \
            "$@")
        listImports "${res[@]}"
    fi
}

# check all required imports exist and are readable
checkImports(){
    local -a imports
    mapfile -t imports < <(listImports "$@")

    local f
    for f in "${imports[@]}"; do
        if [[ -r $f ]]; then
            echo "Imported: $f"
        else
            echo "error: cannot find imported file: $f" >&2
            return 1
        fi
    done
}
