# Theodo Scan
MIT

## Requirements

This tool is a CLI built using bash scripts. All tools used by the bash script are listed below and must be installed on your system.

- Linux or macOS
- Bash 4.0 or higher
- trivy - [Installation Guide](https://trivy.dev/docs/latest/getting-started/installation/)
- jq - [Installation Guide](https://jqlang.github.io/jq/download/)

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
3. Saves the SBOM to `.theodo/sbom.json`
4. Enhances the SBOM with custom metadata based on your `.theodorc` configuration:
   - Updates the component name to `{ORG}-{PROJECT}-{COMPONENT}`
   - Adds structured metadata properties for organization, project, and component

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

All other fields in the SBOM are preserved exactly as generated by Trivy, including:
- Timestamp of the scan
- Trivy version and metadata
- Complete list of components (dependencies)
- Dependency relationships
- Vulnerability data

### Hello Command

Display a hello message and show your current configuration.

**Note:** Requires `.theodorc` file. Run `theodo-scan init` first.

```bash
theodo-scan hello
```

This command validates that your configuration file exists and displays the loaded configuration values.




