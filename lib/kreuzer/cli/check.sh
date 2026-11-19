# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# cli/check.sh - environment report for bug reports and first installs
#
# Depends on : core/deps.sh, config/config.sh, data/store.sh
# Provides   : cli_check

# Notes about truecolor and locale are advisory: the app still starts, but
# colours or box characters may look wrong, which is hard to diagnose from a
# screenshot alone.
cli_check() {
  deps_check; config_apply; store_set_paths
  echo "$APP $VERSION, bash $BASH_VERSION"
  echo "config: $CONF_FILE"
  echo "data:   $DATA"
  [[ ${COLORTERM:-} == *truecolor* || ${COLORTERM:-} == *24bit* ]] || echo "note: COLORTERM does not advertise truecolor; colors may look off"
  [[ $(locale charmap 2>/dev/null) == UTF-8 ]] || echo "note: locale is not UTF-8; run: locale charmap"
  echo "all required tools found"
}
