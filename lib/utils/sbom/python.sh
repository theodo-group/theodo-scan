#!/usr/bin/env bash

# Python SBOM fixes

# Add the develop packages of every Pipfile.lock of the SBOM.
# Trivy only reads the default section of Pipfile.lock; absent from the production SBOM,
# the added packages are then flagged as dev.
add_pipenv_develop_packages() {
    local sbom_file="$1"
    local app_ref lockfile develop

    while IFS=$'\t' read -r app_ref lockfile; do
        [ -f "$lockfile" ] || continue
        print_info "Adding develop packages of ${lockfile}..."

        develop=$(jq '[
            .develop // {} | to_entries[]
            | select(.value.version != null)
            | {name: .key, version: (.value.version | ltrimstr("=="))}
        ]' "$lockfile") || develop="[]"

        if ! jq --arg app "$app_ref" --argjson develop "$develop" '
            ([.components[]?.purl // empty] | map({(.): true}) | add // {}) as $existing
            | [
                $develop[]
                | . + {purl: ("pkg:pypi/" + (.name | ascii_downcase | gsub("[-_.]+"; "-")) + "@" + .version)}
                | select($existing[.purl] | not)
              ] as $new
            | .components = ((.components // []) + [
                $new[] | {
                    "bom-ref": .purl,
                    "type": "library",
                    "name": .name,
                    "version": .version,
                    "purl": .purl,
                    "properties": [{"name": "aquasecurity:trivy:PkgType", "value": "pipenv"}]
                }
              ])
            | .dependencies = (
                ((.dependencies // []) | map(if .ref == $app then .dependsOn += [$new[].purl] else . end))
                + [$new[] | {"ref": .purl, "dependsOn": []}]
              )
        ' "$sbom_file" > "${sbom_file}.tmp"; then
            print_error "Failed to add develop packages of ${lockfile}"
            return 1
        fi

        mv "${sbom_file}.tmp" "$sbom_file"
    done < <(jq -r '
        .components[]?
        | select(.type == "application" and any(.properties[]?; .name == "aquasecurity:trivy:Type" and .value == "pipenv"))
        | [."bom-ref", .name] | @tsv
    ' "$sbom_file")
}
