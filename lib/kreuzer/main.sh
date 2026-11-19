# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# main.sh - bootstrap: runtime environment, module loading, entry point
#
# Defines main() but does not call it. The launcher calls it, and tests can
# source this file without starting the UI.

# User text (search queries, notes) is expanded unquoted in a few places on
# purpose; with globbing off, a '*' typed by the user can never match files.
set -f
# Financial data: files are private to the owner unless the user changes that.
umask 077

APP="kreuzer"
VERSION="0.1.0"

if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4))); then
  echo "$APP needs bash 4.4 or newer" >&2; exit 1
fi

# Fallback so sourcing this file directly (tests) works without the launcher.
: "${KREUZER_LIBDIR:=${BASH_SOURCE[0]%/*}}"

# Dependency order: a module may only use modules listed above it, except that
# function bodies are resolved at call time, so only top-level declarations
# (arrays, constants) are order-sensitive.
KREUZER_MODULES=(
  core/log core/text core/list core/money core/dates core/deps
  config/config config/keys
  ui/theme ui/state
  data/store data/categories data/transactions data/budget data/trash
  domain/balances domain/totals domain/series domain/alerts
  ui/term ui/input ui/canvas ui/widgets ui/form ui/draw
  viz/bars viz/pie viz/blocks viz/entry
  screens/common screens/dashboard screens/transactions screens/daily screens/categories
  screens/wallets screens/budget screens/search screens/trash
  forms/entry forms/transfer forms/category forms/wallet forms/budget forms/settings
  app/actions
  cli/help cli/setup cli/export cli/backup cli/check
)

# This loop must stay at top level (not inside a function), otherwise plain
# `declare` in the modules would create function-local variables.
for _module in "${KREUZER_MODULES[@]}"; do
  if [[ ! -r $KREUZER_LIBDIR/$_module.sh ]]; then
    # printf, not die: core/log may be the module that is missing.
    printf '%s: missing module %s.sh in %s\n' "$APP" "$_module" "$KREUZER_LIBDIR" >&2
    exit 1
  fi
  # shellcheck source=/dev/null
  source "$KREUZER_LIBDIR/$_module.sh"
done
unset _module

# Order is deliberate: informational flags work without a config file, config is
# loaded before anything that needs paths, and the first-run prompt only runs for
# commands that need data, so `--help` never creates files.
main() {
  local cmd=${1:-}
  case $cmd in
    -h | --help) usage; return 0 ;;
    -V | --version) echo "$APP $VERSION"; return 0 ;;
  esac
  load_config
  case $cmd in
    --dump-keys) dump_keys; return 0 ;;
    --check) cmd_check; return 0 ;;
  esac
  check_deps
  [[ -f $CONF_FILE ]] || first_run
  apply_cfg; build_keymap
  case $cmd in
    export) set_paths; cmd_export "${2:-$(date +%Y-%m)}"; return $? ;;
    backup) set_paths; cmd_backup; return $? ;;
    "") ;;
    *) usage >&2; return 1 ;;
  esac
  init_data; ensure_basics; auto_purge
  tui_start; main_loop
}
