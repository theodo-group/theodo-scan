# Theodo Scan
MIT

## Requirements

This tool is a CLI built using bash scripts. All tools used by the bash script are listed below and must be installed on your system.

- Linux or macOS
- Bash 4.0 or higher

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

### Hello Command

Display a hello message and show your current configuration.

**Note:** Requires `.theodorc` file. Run `theodo-scan init` first.

```bash
theodo-scan hello
```

This command validates that your configuration file exists and displays the loaded configuration values.




