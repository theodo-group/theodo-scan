#!/usr/bin/env bash

# Node.js SBOM fixes

# Print the npm workspaces (linked packages) of every npm lockfile of a Trivy JSON report,
# as {"<lockfile>": ["<workspace name>", ...]}.
# Trivy reports npm workspaces as direct dependencies of the root and their own
# dependencies as indirect: the caller needs them to flag those dependencies as direct.
list_npm_workspaces() {
    local packages_file="$1"
    local workspaces="{}"
    local lockfile names

    while IFS= read -r lockfile; do
        [ -f "$lockfile" ] || continue
        names=$(jq '[
            .packages // {} | to_entries[]
            | select(.value.link == true)
            | .key | sub("^(.*/)?node_modules/"; "")
        ]' "$lockfile" 2>/dev/null) || names="[]"
        workspaces=$(jq --arg target "$lockfile" --argjson names "$names" \
            '. + {($target): $names}' <<< "$workspaces")
    done < <(jq -r '.Results[]? | select(.Type == "npm") | .Target' "$packages_file")

    echo "$workspaces"
}
