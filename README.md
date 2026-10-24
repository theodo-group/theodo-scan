# Theodo Scan
MIT

## Requirements

This tool is a CLI built using bash scripts. All tools used by the bash script are listed below and must be installed on your system.

- Linux or macOS
- Bash 4.0 or higher
- trivy - [Installation Guide](https://trivy.dev/docs/latest/getting-started/installation/)
- jq - [Installation Guide](https://jqlang.github.io/jq/download/)
- aws - [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) (required for `upload` command)

## Install

The installation script creates a symlink to the CLI in `/usr/local/bin`, allowing you to run `theodo-scan` from anywhere.

```bash
chmod +x bin/theodo-scan
chmod +x install.sh
chmod +x uninstall.sh
./install.sh
```

ℹ️ The CLI is installed as a symlink, which means it always points to your local repository. 

## Update

This allows you to update the tool by simply pulling the latest changes:

```bash
git checkout main
git pull
```

No need to reinstall after updates!

## Development

1. Install the CLI once using the install script.

2. You can test your changes without reinstalling the CLI by running commands directly from the repository:

```bash
thedo-scan my-new-command
```

## Uninstall

```bash
./uninstall.sh
```

Note: Uninstalling only removes the symlink. Your repository remains intact.

## Available Commands

### Help

```bash
theodo-scan --help
```

### Init Command

Initialize a Theodo Scan configuration file in your project.

```bash
theodo-scan init
```

This command creates a `.theodorc` configuration file in your current directory with default values:
- `THEODO_SCAN_ORG`: Set to your current directory name
- `THEODO_SCAN_PROJECT`: Set to your current directory name
- `THEODO_SCAN_COMPONENT`: Set to "main"
- `THEODO_SCAN_BUCKET_NAME`: S3 bucket name for SBOM uploads (default: `watchtower-prod-s3bucketbucket-ubzdhdmf`)
- `THEODO_SCAN_LOCAL_AWS_PROFILE`: AWS CLI profile for **local** uploads (default: `watchtower`). Ignored in CI — see [ci-setup.md](ci-setup.md).

The component variable is useful for identifying different parts of your project (e.g., 'frontend', 'backend', 'api-service').

After running init, edit `.theodorc` to customize these values for your project.

**Note:** Most commands require a `.theodorc` file. Run `theodo-scan init` in your project directory before using other commands.

### Scan Command

Run a security scan using Trivy and generate a CycloneDX SBOM (Software Bill of Materials).

**Note:** Requires `.theodorc` file. Run `theodo-scan init` first.

```bash
theodo-scan scan
```

This command:
1. Scans the current directory for vulnerabilities and dependencies using Trivy
2. Generates a CycloneDX SBOM (Software Bill of Materials) in JSON format
3. Detects programming languages and runtimes (Node.js, Python, Ruby, Java, Go, PHP)
4. Saves the SBOM to `.theodo/sbom.json`
5. Enhances the SBOM with custom metadata based on your `.theodorc` configuration:
   - Updates the component name to `{ORG}-{PROJECT}-{COMPONENT}`
   - Adds structured metadata properties for organization, project, and component
6. Flags dev-only dependencies with a `theodo:dev` property
7. Flags every library with a `theodo:direct` property (`"true"` for direct dependencies and workspaces, `"false"` for transitive ones)

**Output Location:** `.theodo/sbom.json`

#### SBOM Format

The generated SBOM follows the [CycloneDX 1.6 specification](https://cyclonedx.org/specification/overview/), a widely-adopted standard for Software Bill of Materials. The SBOM is generated in JSON format and contains:

**Structure:**
- `bomFormat`: Always set to "CycloneDX"
- `specVersion`: "1.6"
- `serialNumber`: A unique URN UUID for the SBOM
- `version`: SBOM version number (usually 1 because it is never updated)
- `metadata`: Information about the scan, tools used, and the scanned component
- `components`: List of all dependencies found in the project
- `dependencies`: Dependency tree showing relationships between components
- `vulnerabilities`: List of security vulnerabilities detected in the dependencies

**Example SBOM:**
```json
{
  "$schema": "http://cyclonedx.org/schema/bom-1.6.schema.json",
  "bomFormat": "CycloneDX",
  "specVersion": "1.6",
  "serialNumber": "urn:uuid:0f6e7205-8161-464e-b785-7ab32d8793d8",
  "version": 1,
  "metadata": {
    "timestamp": "2025-12-05T12:42:16+00:00",
    "tools": {},
    "component": {
      "bom-ref": "2ce2e5ed-70ea-4407-a3c7-46d61a27fd7a",
      "type": "application",
      "name": "acme-super-project-backend",
      "properties": [
        {
          "name": "aquasecurity:trivy:SchemaVersion",
          "value": "2"
        }
      ]
    },
    "properties": [
      {
        "name": "theodo:org",
        "value": "acme"
      },
      {
        "name": "theodo:project",
        "value": "super-project"
      },
      {
        "name": "theodo:component",
        "value": "backend"
      }
    ]
  },
  "components": [],
  "dependencies": [
    {
      "ref": "2ce2e5ed-70ea-4407-a3c7-46d61a27fd7a",
      "dependsOn": []
    }
  ],
  "vulnerabilities": []
}
```

#### CLI Modifications to SBOM

The `theodo-scan scan` command makes the following modifications to the Trivy-generated SBOM:

1. **Component Name Override**: The `metadata.component.name` field is modified to follow the naming convention: `{THEODO_SCAN_ORG}-{THEODO_SCAN_PROJECT}-{THEODO_SCAN_COMPONENT}`

   This allows you to:
   - Uniquely identify different components of your project
   - Track multiple SBOMs from the same organization and project
   - Differentiate between frontend, backend, and other services

2. **Custom Metadata Properties**: The `metadata.properties` array is enhanced with three custom properties following CycloneDX standards:
   - `theodo:org` - Contains the value of `THEODO_SCAN_ORG` from your `.theodorc` file
   - `theodo:project` - Contains the value of `THEODO_SCAN_PROJECT` from your `.theodorc` file
   - `theodo:component` - Contains the value of `THEODO_SCAN_COMPONENT` from your `.theodorc` file

   These properties provide structured, queryable metadata that can be used for:
   - SBOM aggregation and reporting across multiple components
   - Filtering and organizing SBOMs by organization, project, or component
   - Integration with SBOM management tools and platforms
   - Policy enforcement based on organizational structure

   **Technical Implementation:** Uses `jq` to update the component name and add custom properties after Trivy generates the initial SBOM. The `theodo:` namespace prefix follows CycloneDX best practices for custom properties and prevents conflicts with other tools.

3. **Dev-Only Dependency Flagging**: Components that are only used as development dependencies are tagged with a `theodo:dev` property set to `"true"` in the component's `properties` array. Production dependencies are left untagged.

   **Technical Implementation:** Trivy is run twice — once without `--include-dev-deps` (production-only) and once with it (all dependencies). Any component present in the full SBOM but absent from the production SBOM is considered dev-only and flagged. The intermediate production SBOM is removed after the diff.

4. **Direct Dependency Flagging**: Every component of type `library` is tagged with a `theodo:direct` property in its `properties` array: `"true"` when it is a direct dependency of the project or one of its workspaces, `"false"` when it is only pulled in transitively. Every library is tagged, so a consumer can tell a transitive dependency (`"false"`) from an SBOM produced before this property existed (property absent).

   **Technical Implementation:** The CycloneDX SBOM does not tell direct and transitive dependencies apart, so Trivy is run a third time with `--list-all-pkgs --format json`, whose report carries a `Relationship` for each package. The PURLs of packages whose relationship is `direct` or `workspace` are collected, along with the dependencies of every workspace, and each SBOM library is flagged according to whether its `purl` is in that set. The intermediate JSON report is removed afterwards.

   **npm workspaces:** with `package-lock.json`, Trivy reports workspaces as direct dependencies of the root and their own dependencies as indirect. Workspaces are therefore read from the lockfile (entries with `"link": true`) so that the dependencies they declare are flagged as direct, as they are with pnpm and yarn. The project root itself (yarn's `root` relationship) is flagged `"false"`.

#### Language Detection

The scan command automatically detects programming languages and runtimes used in your project and adds them as framework components in the SBOM.

**Supported Languages:**
- **Node.js**: Detected via `.nvmrc`, `.node-version`, or `package.json`
- **Python**: Detected via `.python-version`, `requirements.txt`, `Pipfile`, or `pyproject.toml`
- **Java**: Detected via `pom.xml`, `build.gradle`, or `.java` files
- **PHP**: Detected via `composer.json` or `.php` files

**Version Resolution:**
1. Checks for version files (`.nvmrc`, `.python-version`, etc.)
2. For `.nvmrc`, resolves LTS aliases to actual versions:
   - `lts/jod` → `v22.21.1` (Node.js 22 LTS)
   - `lts/iron` → `v20.18.1` (Node.js 20 LTS)
   - `lts/hydrogen` → `v18.20.5` (Node.js 18 LTS)
   - `lts/gallium` → `v16.20.2` (Node.js 16 LTS)
3. Falls back to installed runtime version if no version file found
4. Emits warning when using installed version instead of version file

**SBOM Integration:**
Detected languages are added to the `components` array with:
- `type`: "framework"
- `name`: Language name (e.g., "nodejs", "python")
- `version`: Detected version (e.g., "22.21.1")
- `purl`: Package URL in format `pkg:generic/{language}@{version}`
- `bom-ref`: Unique identifier in format `lang-{language}-{version}`

Languages are also added to the main component's dependency tree in the `dependencies` section.

**Example SBOM with Language Detection:**
```json
{
  "components": [
    {
      "type": "framework",
      "bom-ref": "lang-nodejs-22.21.1",
      "name": "nodejs",
      "version": "22.21.1",
      "purl": "pkg:generic/nodejs@22.21.1"
    },
    {
      "type": "framework",
      "bom-ref": "lang-python-3.11.6",
      "name": "python",
      "version": "3.11.6",
      "purl": "pkg:generic/python@3.11.6"
    }
  ],
  "dependencies": [
    {
      "ref": "2ce2e5ed-70ea-4407-a3c7-46d61a27fd7a",
      "dependsOn": [
        "lang-nodejs-22.21.1",
        "lang-python-3.11.6"
      ]
    }
  ]
}
```

### Run Command

Run a security scan and upload the resulting SBOM to S3 in one step.

**Note:** Requires `.theodorc` file. Run `theodo-scan init` first.

```bash
theodo-scan run
```

This command is a convenience shortcut that runs `scan` followed by `upload`.

**Options:**

| Flag | Description |
|------|-------------|
| `-b, --bucket <name>` | S3 bucket name (overrides `.theodorc`) |
| `-p, --profile <name>` | AWS CLI profile to use (local only; overrides `.theodorc`) |
| `-h, --help` | Show help message |

**Examples:**

```bash
theodo-scan run
theodo-scan run --bucket my-bucket --profile my-aws-profile
```

In CI, omit `--profile` and configure credentials via OIDC or environment variables — see [ci-setup.md](ci-setup.md).

### Upload Command

Upload an SBOM file to an S3 bucket.

**Note:** Requires `.theodorc` file. Run `theodo-scan init` first.

```bash
theodo-scan upload
```

The SBOM is uploaded to `s3://<bucket>/sboms/<org>-<project>-<component>/theodo-scan-sbom.json`, where `<org>`, `<project>`, and `<component>` are extracted from the SBOM's `metadata.properties`.

**Options:**

| Flag | Description |
|------|-------------|
| `-b, --bucket <name>` | S3 bucket name (overrides `.theodorc`) |
| `-f, --file <path>` | Path to SBOM file (default: `.theodo/sbom.json`) |
| `-p, --profile <name>` | AWS CLI profile to use (local only; overrides `.theodorc`) |
| `-h, --help` | Show help message |

**Configuration:**

The bucket name and (local) AWS profile can be configured in `.theodorc`:
- `THEODO_SCAN_BUCKET_NAME`: S3 bucket name for SBOM uploads
- `THEODO_SCAN_LOCAL_AWS_PROFILE`: AWS CLI profile to use for local runs (ignored in CI)

Command-line flags (`--bucket`, `--profile`) take precedence over `.theodorc` values.

**Examples:**

```bash
theodo-scan upload
theodo-scan upload --bucket my-bucket
theodo-scan upload --bucket my-bucket --profile my-aws-profile
theodo-scan upload --bucket my-bucket --file ./custom-sbom.json
```

#### CI usage

For CI behavior, AWS authentication (OIDC + IAM role policy), and copy-pasteable per-provider job snippets (GitHub Actions, GitLab CI, Bitbucket Pipelines, Azure Pipelines), see [ci-setup.md](ci-setup.md).

### Hello Command

Display a hello message and show your current configuration.

**Note:** Requires `.theodorc` file. Run `theodo-scan init` first.

```bash
theodo-scan hello
```

This command validates that your configuration file exists and displays the loaded configuration values.




