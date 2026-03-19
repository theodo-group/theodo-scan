# Theodo Scan agent file

This repository contains Theodo Scan, a command-line interface (CLI) tool built with bash scripts. 
The tool is designed to work on Linux and macOS systems.
When you modify a command, update the corresponding documentation in the `README.md` file and `show_help` in `bin/theodo-scan` to reflect the changes.
If a new dependency is added to the project, please make sure to update the Requirements in the `README.md` file accordingly.
The cli is installed as a symlink, which means it always points to the local `bin/theodo-scan` from this folder.
Ensure all bash scripts are written to be executed from everywhere the script is called from.
Don't forget to update `README.md` at the end.
