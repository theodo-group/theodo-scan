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
4. Updates the component name in the SBOM metadata to `{ORG}-{PROJECT}-{COMPONENT}` based on your `.theodorc` configuration

The SBOM includes:
- Complete list of project dependencies (components)
- Dependency relationships
- Known vulnerabilities
- Metadata about the scan and tools used

The component name in the SBOM will be formatted as: `THEODO_SCAN_ORG-THEODO_SCAN_PROJECT-THEODO_SCAN_COMPONENT`

**Example:**
If your `.theodorc` contains:
- `THEODO_SCAN_ORG="acme-corp"`
- `THEODO_SCAN_PROJECT="web-api"`
- `THEODO_SCAN_COMPONENT="backend"`

The SBOM will have `metadata.component.name` set to: `"acme-corp-web-api-backend"`

**Output Location:** `.theodo/sbom.json`

### Hello Command

Display a hello message and show your current configuration.

**Note:** Requires `.theodorc` file. Run `theodo-scan init` first.

```bash
theodo-scan hello
```

This command validates that your configuration file exists and displays the loaded configuration values.




