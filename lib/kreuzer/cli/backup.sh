# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# cli/backup.sh - timestamped archive of the data directory
#
# Depends on : data/store.sh paths (store_set_paths), log_die
# Provides   : cli_backup

# The archive is written next to the data directory, not inside it, so a backup
# never contains older backups. -C keeps the stored paths relative.
cli_backup() {
  local out="$DATA.$(date +%Y%m%d-%H%M%S).tar.gz"
  [[ -d $DATA ]] || log_die "no data directory at $DATA"
  tar -czf "$out" -C "${DATA%/*}" "${DATA##*/}" && echo "$out"
}
