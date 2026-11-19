# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# cli/help.sh - command-line help text
#
# Depends on : APP VERSION CONF_FILE
# Provides   : usage

# Plain text on stdout so it works in pipes and before any config exists.
usage() {
  cat <<EOF
$APP $VERSION - income, expense and budget tracker

Usage: $APP [command]
  (none)             start the interactive interface
  export [YYYY-MM]   print a month as CSV
  backup             create a .tar.gz of the data directory next to it
  --dump-keys        print the key bindings in effect
  --check            check dependencies and show paths
  -V, --version      print the version
  -h, --help         show this help

Data    ~/Documents/$APP (data_dir in the config)
Config  $CONF_FILE
Inside the app press ? for the key list. NO_COLOR disables UI colors.
EOF
}
