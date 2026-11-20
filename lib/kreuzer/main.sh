# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# main.sh - bootstrap: runtime environment, module loading, entry point
#
# Defines main() but does not call it. The launcher does, and tests can source
# this file without starting the UI.

# User text (search queries, notes) is expanded unquoted in a few places on
# purpose. With globbing off, a '*' typed by the user can never match files.
set -f
# Financial data: private to the owner unless the user changes that.
umask 077

APP="kreuzer"
VERSION="0.1.0"

if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4))); then
  echo "$APP needs bash 4.4 or newer" >&2; exit 1
fi

# Lets tests source this file directly, without the launcher.
: "${KREUZER_LIBDIR:=${BASH_SOURCE[0]%/*}}"

# Load order. Function bodies are resolved at call time, so only top-level
# declarations (arrays, constants) depend on this order.
KREUZER_MODULES=(
  core/log core/text core/list core/money core/dates core/deps
  config/config config/keys
  ui/theme ui/state
  data/store data/categories data/wallets data/transactions data/budget data/trash
  domain/balances domain/totals domain/series domain/alerts
  ui/term ui/input ui/canvas ui/widgets ui/form ui/draw
  viz/bars viz/pie viz/blocks viz/entry
  screens/common screens/dashboard screens/transactions screens/daily screens/categories
  screens/wallets screens/budget screens/search screens/trash
  forms/entry forms/transfer forms/category forms/wallet forms/budget forms/settings
  app/actions
  cli/help cli/setup cli/export cli/backup cli/check
)

# Must stay at top level: inside a function, `declare` in the modules would
# create function-local variables. The bundled build (tools/dist.sh) has the
# modules inline already and sets KREUZER_BUNDLED to skip loading.
if [[ -z ${KREUZER_BUNDLED:-} ]]; then
  for _module in "${KREUZER_MODULES[@]}"; do
    if [[ ! -r $KREUZER_LIBDIR/$_module.sh ]]; then
      # printf, not log_die: core/log may be the missing module.
      printf '%s: missing module %s.sh in %s\n' "$APP" "$_module" "$KREUZER_LIBDIR" >&2
      exit 1
    fi
    # shellcheck source=/dev/null
    source "$KREUZER_LIBDIR/$_module.sh"
  done
  unset _module
fi

# Informational flags work without a config file, and the first-run questions
# only run for commands that need data, so --help never creates files.
main() {
  local cmd=${1:-}
  case $cmd in
    -h | --help) cli_usage; return 0 ;;
    -V | --version) echo "$APP $VERSION"; return 0 ;;
  esac
  config_load
  case $cmd in
    --dump-keys) keys_dump; return 0 ;;
    --check) cli_check; return 0 ;;
  esac
  deps_check
  [[ -f $CONF_FILE ]] || cli_first_run
  config_apply; keys_build
  case $cmd in
    export) store_set_paths; cli_export "${2:-$(date +%Y-%m)}"; return $? ;;
    backup) store_set_paths; cli_backup; return $? ;;
    "") ;;
    *) cli_usage >&2; return 1 ;;
  esac
  store_init; cli_ensure_basics; store_auto_purge
  term_start; main_loop
}
