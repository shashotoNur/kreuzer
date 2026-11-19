# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# screens/search.sh - search across all months
#
# Depends on : data/transactions.sh (tx_parse_query, tx_load), screens/common.sh
# Provides   : screen_search_load screen_search_row screen_search_title screen_search_viz

screen_search_load() {
  tx_parse_query "$QUERY"
  local -a mf; mapfile -t mf < <(store_months)
  if ((${#mf[@]})); then tx_load "${mf[@]}"; else TX=(); fi
  ROWS_DATA=("${TX[@]}"); SELECTABLE=1
}

screen_search_row() { screen_row_tx "$1"; }

screen_search_title() { screen_title_tx "Search - query: ${QUERY:-(all)}"; }

# The pies cover the matches only, so a search doubles as a quick report.
screen_search_viz() { pie_selected_category; block_pies "$VY" "$VH" TX " (matches)"; }
