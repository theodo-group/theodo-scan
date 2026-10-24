#!/usr/bin/env bash

# Java SBOM fixes

# Add the Maven test-scope dependencies to the SBOM and to the Trivy JSON report.
# Trivy drops them: scan a copy of the pom.xml files where the test scope is turned into
# compile scope, and add what it finds (absent from the production SBOM, the added
# packages are then flagged as dev).
add_maven_test_dependencies() {
    local sbom_file="$1"
    local packages_file="$2"
    local test_scope_pattern='<scope>[[:space:]]*test[[:space:]]*</scope>'
    local pom_files=()
    local has_test_scope=false
    local pom

    while IFS= read -r pom; do
        pom_files+=("$pom")
        if grep -qE "$test_scope_pattern" "$pom"; then
            has_test_scope=true
        fi
    done < <(find . -name pom.xml -not -path '*/node_modules/*' -not -path '*/target/*' -not -path '*/.git/*')

    if [ "$has_test_scope" != true ]; then
        return 0
    fi

    print_info "Running Trivy scan (Maven test dependencies)..."
    echo ""

    local test_dir
    if ! test_dir=$(mktemp -d) || [ -z "$test_dir" ]; then
        print_error "Failed to create a temporary directory"
        return 1
    fi

    local test_sbom_file test_packages_file
    test_sbom_file="$(pwd)/$(dirname "$sbom_file")/sbom.maven-test.json"
    test_packages_file="$(pwd)/$(dirname "$packages_file")/packages.maven-test.json"

    for pom in "${pom_files[@]}"; do
        mkdir -p "${test_dir}/$(dirname "$pom")"
        sed -E "s#${test_scope_pattern}#<scope>compile</scope>#g" "$pom" > "${test_dir}/${pom}"
    done

    if ! (cd "$test_dir" \
        && trivy fs --include-dev-deps --format cyclonedx -o "$test_sbom_file" . \
        && trivy fs --scanners "" --include-dev-deps --list-all-pkgs --format json -o "$test_packages_file" .); then
        rm -rf "${test_dir:?}"
        print_error "Trivy scan failed (Maven test dependencies)"
        return 1
    fi

    rm -rf "${test_dir:?}"
    echo ""

    # Add the missing libraries (one per purl) and merge the dependency graph. Both SBOMs
    # are matched by purl: Trivy gives a random bom-ref to packages listed by several
    # pom.xml files (multi-module projects)
    if ! jq --slurpfile test "$test_sbom_file" '
        $test[0] as $t
        | ([$t.components[]? | select(.purl != null) | {key: ."bom-ref", value: .purl}] | from_entries) as $testRefToPurl
        | ([.components[]? | select(.purl != null) | {key: ."bom-ref", value: .purl}] | from_entries) as $refToPurl
        | ([.components[]? | select(.purl != null)] | group_by(.purl) | map({key: .[0].purl, value: .[0]."bom-ref"}) | from_entries) as $purlToRef
        | ([
            $t.components[]?
            | select(.type == "library" and .purl != null and ($purlToRef[.purl] | not))
          ] | group_by(.purl) | map(.[0] | ."bom-ref" = .purl)) as $new
        | ($purlToRef + ($new | map({key: .purl, value: .purl}) | from_entries)) as $purlToRef
        | ([
            $t.dependencies[]?
            | select($testRefToPurl[.ref] != null)
            | {purl: $testRefToPurl[.ref], dependsOn: [.dependsOn[]? | $testRefToPurl[.] // empty | $purlToRef[.] // empty]}
          ] | group_by(.purl) | map({key: .[0].purl, value: (map(.dependsOn[]) | unique)}) | from_entries) as $testDeps
        | .components = ((.components // []) + $new)
        | .dependencies = (
            ((.dependencies // []) | map(
                ([.dependsOn[]? | $refToPurl[.] // .]) as $existingPurls
                | [
                    ($testDeps[$refToPurl[.ref] // ""] // [])[]
                    | select(($refToPurl[.] // .) as $p | $existingPurls | index($p) | not)
                  ] as $added
                | if ($added | length) > 0 then .dependsOn = ((.dependsOn // []) + $added | unique) else . end
            ))
            + [$new[] | {"ref": ."bom-ref", "dependsOn": ($testDeps[.purl] // [])}]
          )
    ' "$sbom_file" > "${sbom_file}.tmp"; then
        print_error "Failed to add Maven test dependencies"
        return 1
    fi

    mv "${sbom_file}.tmp" "$sbom_file"

    if ! jq -s '.[0].Results = ((.[0].Results // []) + (.[1].Results // [])) | .[0]' \
        "$packages_file" "$test_packages_file" > "${packages_file}.tmp"; then
        print_error "Failed to add Maven test dependencies to the package listing"
        return 1
    fi

    mv "${packages_file}.tmp" "$packages_file"
    rm -f "$test_sbom_file" "$test_packages_file"
}
