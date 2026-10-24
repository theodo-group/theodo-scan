#!/usr/bin/env bash

# SBOM regression tests
#
# Runs `theodo-scan scan` on every project in tests/fixtures/ and compares the
# normalized SBOM with tests/expected/<fixture>.json.
#
# Usage:
#   tests/run.sh [--update] [fixture...]
#
#   --update    Overwrite the expected SBOMs with the current output

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$(cd "$TESTS_DIR/.." && pwd)/bin/theodo-scan"
FIXTURES_DIR="$TESTS_DIR/fixtures"
EXPECTED_DIR="$TESTS_DIR/expected"

# Trivy version the expected SBOMs were generated with
EXPECTED_TRIVY_VERSION="0.76.1"

# Keep only what theodo-scan is responsible for: components and their theodo:
# properties. Drops serial numbers, timestamps, UUID bom-refs and Trivy metadata.
NORMALIZE_FILTER='{
    metadata: {
        name: .metadata.component.name,
        properties: [.metadata.properties[]? | select(.name | startswith("theodo:"))] | sort_by(.name)
    },
    components: [
        .components[]?
        | {
            type,
            group,
            name,
            version,
            purl,
            properties: [.properties[]? | select(.name | startswith("theodo:"))] | sort_by(.name)
          }
        | with_entries(select(.value != null))
    ] | sort_by(.type, .group // "", .name, .version // "", .purl // "", (.properties | tostring))
}'

update=false
fixtures=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --update)
            update=true
            shift
            ;;
        -h|--help)
            sed -n '3,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            fixtures+=("$1")
            shift
            ;;
    esac
done

if [ ${#fixtures[@]} -eq 0 ]; then
    for dir in "$FIXTURES_DIR"/*/; do
        fixtures+=("$(basename "$dir")")
    done
fi

trivy_version=$(trivy --version 2>/dev/null | sed -n 's/^Version: //p')
if [ "$trivy_version" != "$EXPECTED_TRIVY_VERSION" ]; then
    echo "Warning: expected SBOMs were generated with Trivy $EXPECTED_TRIVY_VERSION, running Trivy ${trivy_version:-unknown}" >&2
fi

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

mkdir -p "$EXPECTED_DIR"
failures=0

for fixture in "${fixtures[@]}"; do
    if [ ! -d "$FIXTURES_DIR/$fixture" ]; then
        echo "✗ $fixture: no such fixture"
        failures=$((failures + 1))
        continue
    fi

    # Scan a copy so that .theodo/ is never written in the repository
    project="$work_dir/$fixture"
    cp -R "$FIXTURES_DIR/$fixture" "$project"

    if ! (cd "$project" && "$CLI" scan > "$work_dir/$fixture.log" 2>&1); then
        echo "✗ $fixture: scan failed"
        sed 's/^/    /' "$work_dir/$fixture.log"
        failures=$((failures + 1))
        continue
    fi

    actual="$work_dir/$fixture.json"
    jq "$NORMALIZE_FILTER" "$project/.theodo/sbom.json" > "$actual"

    expected="$EXPECTED_DIR/$fixture.json"

    if [ "$update" = true ]; then
        cp "$actual" "$expected"
        echo "↻ $fixture: expected SBOM updated"
    elif [ ! -f "$expected" ]; then
        echo "✗ $fixture: missing $expected (run with --update)"
        failures=$((failures + 1))
    elif diff -u "$expected" "$actual" > "$work_dir/$fixture.diff"; then
        echo "✓ $fixture"
    else
        echo "✗ $fixture: SBOM differs from expected"
        sed 's/^/    /' "$work_dir/$fixture.diff"
        failures=$((failures + 1))
    fi
done

if [ "$failures" -gt 0 ]; then
    echo ""
    echo "$failures fixture(s) failed"
    exit 1
fi
