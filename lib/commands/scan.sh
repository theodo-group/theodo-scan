#!/usr/bin/env bash

# Scan command implementation

cmd_scan() {
    local show_help=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Run 'theodo-scan scan --help' for usage information."
                exit 1
                ;;
        esac
    done

    # Show help if requested
    if [ "$show_help" = true ]; then
        cat << EOF
Usage: theodo-scan scan [options]

Run a security scan using Trivy and generate a CycloneDX SBOM (Software Bill of Materials).

This command:
  1. Scans the current directory for vulnerabilities and dependencies
  2. Detects programming languages and runtimes (Node.js, Python, Ruby, Java, Go, PHP)
  3. Generates an SBOM in CycloneDX format at .theodo/sbom.json
  4. Updates the component name with your project identification
  5. Adds detected languages as framework components in the SBOM
  6. Flags dev-only dependencies with a "theodo:dev" property
  7. Flags libraries with a "theodo:direct" property ("true" for direct
     dependencies and workspaces, "false" for transitive ones, absent when
     the lockfile does not tell)

Options:
    -h, --help          Show this help message

Examples:
    theodo-scan scan

Note: Requires .theodorc file. Run 'theodo-scan init' first.
Required dependencies: trivy, jq

EOF
        exit 0
    fi

    # Validate and load configuration
    validate_theodorc_config

    # Check required dependencies
    check_scan_dependencies

    # Display scan header
    print_header "🔍 Theodo Scan - Security Scan"
    echo ""

    # Define output paths
    SBOM_DIR=".theodo"
    SBOM_FILE="${SBOM_DIR}/sbom.json"
    SBOM_PROD_FILE="${SBOM_DIR}/sbom.prod.json"
    PACKAGES_FILE="${SBOM_DIR}/packages.json"

    # Create .theodo directory if it doesn't exist
    if [ ! -d "$SBOM_DIR" ]; then
        mkdir -p "$SBOM_DIR"
        print_info "Created directory: $SBOM_DIR"
    fi

    # Run Trivy scan (production dependencies only, used to identify dev-only deps)
    print_info "Running Trivy scan (production dependencies)..."
    echo ""

    if ! trivy fs --format cyclonedx -o "${SBOM_PROD_FILE}" .; then
        print_error "Trivy scan failed (production dependencies)"
        exit 1
    fi

    echo ""

    # Run Trivy scan (all dependencies including dev)
    print_info "Running Trivy scan (all dependencies including dev)..."
    echo ""

    if ! trivy fs --include-dev-deps --format cyclonedx -o "${SBOM_FILE}" .; then
        print_error "Trivy scan failed"
        exit 1
    fi

    echo ""

    # Run Trivy package listing (JSON report exposes the direct/indirect relationship, the SBOM does not)
    print_info "Running Trivy package listing (direct dependencies)..."
    echo ""

    if ! trivy fs --scanners "" --include-dev-deps --list-all-pkgs --format json -o "${PACKAGES_FILE}" .; then
        print_error "Trivy package listing failed"
        exit 1
    fi

    echo ""

    # Trivy only reads the default section of Pipfile.lock: add the develop packages
    # (absent from the production SBOM, they are then flagged as dev)
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
        ' "${SBOM_FILE}" > "${SBOM_FILE}.tmp"; then
            print_error "Failed to add develop packages of ${lockfile}"
            exit 1
        fi

        mv "${SBOM_FILE}.tmp" "${SBOM_FILE}"
    done < <(jq -r '
        .components[]?
        | select(.type == "application" and any(.properties[]?; .name == "aquasecurity:trivy:Type" and .value == "pipenv"))
        | [."bom-ref", .name] | @tsv
    ' "${SBOM_FILE}")

    # Trivy drops Maven test-scope dependencies: scan a copy of the pom.xml files where the
    # test scope is turned into compile scope, and add what it finds to the SBOM and to the
    # package listing (absent from the production SBOM, the added packages are flagged as dev)
    TEST_SCOPE_PATTERN='<scope>[[:space:]]*test[[:space:]]*</scope>'
    POM_FILES=()
    HAS_TEST_SCOPE=false
    while IFS= read -r pom; do
        POM_FILES+=("$pom")
        if grep -qE "$TEST_SCOPE_PATTERN" "$pom"; then
            HAS_TEST_SCOPE=true
        fi
    done < <(find . -name pom.xml -not -path '*/node_modules/*' -not -path '*/target/*' -not -path '*/.git/*')

    if [ "$HAS_TEST_SCOPE" = true ]; then
        print_info "Running Trivy scan (Maven test dependencies)..."
        echo ""

        if ! MAVEN_TEST_DIR=$(mktemp -d) || [ -z "$MAVEN_TEST_DIR" ]; then
            print_error "Failed to create a temporary directory"
            exit 1
        fi
        MAVEN_TEST_SBOM_FILE="$(pwd)/${SBOM_DIR}/sbom.maven-test.json"
        MAVEN_TEST_PACKAGES_FILE="$(pwd)/${SBOM_DIR}/packages.maven-test.json"

        for pom in "${POM_FILES[@]}"; do
            mkdir -p "${MAVEN_TEST_DIR}/$(dirname "$pom")"
            sed -E "s#${TEST_SCOPE_PATTERN}#<scope>compile</scope>#g" "$pom" > "${MAVEN_TEST_DIR}/${pom}"
        done

        if ! (cd "$MAVEN_TEST_DIR" \
            && trivy fs --include-dev-deps --format cyclonedx -o "${MAVEN_TEST_SBOM_FILE}" . \
            && trivy fs --scanners "" --include-dev-deps --list-all-pkgs --format json -o "${MAVEN_TEST_PACKAGES_FILE}" .); then
            rm -rf "${MAVEN_TEST_DIR:?}"
            print_error "Trivy scan failed (Maven test dependencies)"
            exit 1
        fi

        rm -rf "${MAVEN_TEST_DIR:?}"
        echo ""

        # Add the missing libraries (one per purl) and merge the dependency graph. Both SBOMs
        # are matched by purl: Trivy gives a random bom-ref to packages listed by several
        # pom.xml files (multi-module projects)
        if ! jq --slurpfile test "${MAVEN_TEST_SBOM_FILE}" '
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
        ' "${SBOM_FILE}" > "${SBOM_FILE}.tmp"; then
            print_error "Failed to add Maven test dependencies"
            exit 1
        fi

        mv "${SBOM_FILE}.tmp" "${SBOM_FILE}"

        if ! jq -s '.[0].Results = ((.[0].Results // []) + (.[1].Results // [])) | .[0]' \
            "${PACKAGES_FILE}" "${MAVEN_TEST_PACKAGES_FILE}" > "${PACKAGES_FILE}.tmp"; then
            print_error "Failed to add Maven test dependencies to the package listing"
            exit 1
        fi

        mv "${PACKAGES_FILE}.tmp" "${PACKAGES_FILE}"
        rm -f "${MAVEN_TEST_SBOM_FILE}" "${MAVEN_TEST_PACKAGES_FILE}"
    fi

    # Flag dev-only components (present in full SBOM but not in production SBOM)
    print_info "Flagging dev-only dependencies..."

    # Compared by purl: components listed by several lockfiles, and lockfile components,
    # get a random UUID bom-ref that differs between the two runs
    PROD_PURLS=$(jq '[.components[]?.purl // empty] | unique | map({(.): true}) | add // {}' "${SBOM_PROD_FILE}")

    if ! jq --argjson prod "${PROD_PURLS}" '
        .components |= map(
            if .purl == null or $prod[.purl] then
                .
            else
                .properties = ((.properties // []) + [{"name": "theodo:dev", "value": "true"}])
            end
        )
    ' "${SBOM_FILE}" > "${SBOM_FILE}.tmp"; then
        print_error "Failed to flag dev-only dependencies"
        exit 1
    fi

    mv "${SBOM_FILE}.tmp" "${SBOM_FILE}"
    rm -f "${SBOM_PROD_FILE}"

    echo ""

    # Flag every library component as direct or not
    print_info "Flagging direct dependencies..."

    # Trivy reports npm workspaces as direct dependencies of the root and their own
    # dependencies as indirect: list npm workspaces (linked packages) per lockfile
    NPM_WORKSPACES="{}"
    while IFS= read -r lockfile; do
        [ -f "$lockfile" ] || continue
        names=$(jq '[
            .packages // {} | to_entries[]
            | select(.value.link == true)
            | .key | sub("^(.*/)?node_modules/"; "")
        ]' "$lockfile" 2>/dev/null) || names="[]"
        NPM_WORKSPACES=$(jq --arg target "$lockfile" --argjson names "$names" \
            '. + {($target): $names}' <<< "$NPM_WORKSPACES")
    done < <(jq -r '.Results[]? | select(.Type == "npm") | .Target' "${PACKAGES_FILE}")

    # Direct = direct or workspace packages, plus dependencies declared by a workspace.
    # Lockfiles without a dependency graph (requirements.txt, Pipfile.lock, gradle.lockfile)
    # report no relationship: those packages are left unflagged rather than flagged "false".
    # Result: {purl: "true" | "false"}, purls with an unknown relationship are absent
    DIRECT_FLAGS=$(jq --argjson npmWorkspaces "${NPM_WORKSPACES}" '[
        .Results[]?
        | .Target as $target
        | (.Packages // []) as $packages
        | ($npmWorkspaces[$target] // []) as $workspaceNames
        | ($packages
            | map(select(.Relationship == "workspace" or (.Name as $n | $workspaceNames | index($n))))
            | map(.DependsOn // []) | add // []
          ) as $workspaceDeps
        | $packages[]
        | select(.Identifier.PURL != null)
        | {
            purl: .Identifier.PURL,
            flag: (
                if .Relationship == "direct" or .Relationship == "workspace"
                    or (.ID as $id | $workspaceDeps | index($id)) then "true"
                elif .Relationship == "root" or .Relationship == "indirect" then "false"
                else "unknown"
                end
            )
          }
    ]
    | group_by(.purl)
    | map({
        key: .[0].purl,
        value: (map(.flag) | if index("true") then "true" elif index("unknown") then null else "false" end)
      })
    | map(select(.value != null))
    | from_entries' "${PACKAGES_FILE}")

    if ! jq --argjson flags "${DIRECT_FLAGS}" '
        .components |= map(
            if .type == "library" and .purl != null and $flags[.purl] != null then
                .properties = ((.properties // []) + [{"name": "theodo:direct", "value": $flags[.purl]}])
            else
                .
            end
        )
    ' "${SBOM_FILE}" > "${SBOM_FILE}.tmp"; then
        print_error "Failed to flag direct dependencies"
        exit 1
    fi

    mv "${SBOM_FILE}.tmp" "${SBOM_FILE}"
    rm -f "${PACKAGES_FILE}"

    echo ""

    # Modify SBOM component name and add metadata properties
    COMPONENT_NAME="${THEODO_SCAN_ORG}-${THEODO_SCAN_PROJECT}-${THEODO_SCAN_COMPONENT}"
    print_info "Updating SBOM metadata..."
    print_info "  - Component name: $COMPONENT_NAME"
    print_info "  - Organization: $THEODO_SCAN_ORG"
    print_info "  - Project: $THEODO_SCAN_PROJECT"
    print_info "  - Component: $THEODO_SCAN_COMPONENT"

    if ! jq --arg name "${COMPONENT_NAME}" \
            --arg org "${THEODO_SCAN_ORG}" \
            --arg project "${THEODO_SCAN_PROJECT}" \
            --arg component "${THEODO_SCAN_COMPONENT}" '
        .metadata.component.name = $name |
        .metadata.properties = (.metadata.properties // []) |
        .metadata.properties += [
            {"name": "theodo:org", "value": $org},
            {"name": "theodo:project", "value": $project},
            {"name": "theodo:component", "value": $component}
        ]
    ' "${SBOM_FILE}" > "${SBOM_FILE}.tmp"; then
        print_error "Failed to update SBOM metadata"
        exit 1
    fi

    mv "${SBOM_FILE}.tmp" "${SBOM_FILE}"

    # Detect and add programming languages as framework components
    echo ""
    print_info "Detecting programming languages..."

    DETECTED_LANGUAGES=$(detect_project_languages)

    if [ -n "$DETECTED_LANGUAGES" ] && [ "$DETECTED_LANGUAGES" != "[]" ]; then
        print_info "Adding detected languages to SBOM..."

        if ! jq --argjson languages "${DETECTED_LANGUAGES}" '
            # Add language components to the components array
            .components = ((.components // []) + $languages) |

            # Add language bom-refs to main component dependencies
            .dependencies[0].dependsOn = (
                (.dependencies[0].dependsOn // []) +
                ($languages | map(."bom-ref"))
            )
        ' "${SBOM_FILE}" > "${SBOM_FILE}.tmp"; then
            print_error "Failed to add language components to SBOM"
            exit 1
        fi

        mv "${SBOM_FILE}.tmp" "${SBOM_FILE}"
        print_success "Language detection complete"
    else
        print_info "No languages detected"
    fi

    # Display success message
    echo ""
    print_success "SBOM generated successfully!"
    print_info "SBOM saved to: ${SBOM_FILE}"
    echo ""
}

