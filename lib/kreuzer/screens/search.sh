# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# screens/search.sh - search across all months
#
# Depends on : data/transactions.sh (parse_query, load_tx), screens/common.sh
# Provides   : load_search row_search title_search viz_search

load_search() {
  parse_query "$QUERY"
  local -a mf; mapfile -t mf < <(all_months)
  if ((${#mf[@]})); then load_tx "${mf[@]}"; else TX=(); fi
  ROWS_DATA=("${TX[@]}"); SELECTABLE=1
}

row_search() { row_tx "$1"; }

title_search() { title_tx "Search - query: ${QUERY:-(all)}"; }

# The pies cover the matches only, so a search doubles as a quick report.
viz_search() { sel_cat; viz_pair "$VY" "$VH" TX " (matches)"; }
