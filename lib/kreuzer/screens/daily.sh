# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# screens/daily.sh - one day: its transactions, pies and a month-at-a-glance strip
#
# Depends on : data/transactions.sh, domain/series.sh, viz/*, screens/common.sh
# Provides   : screen_daily_load screen_daily_row screen_daily_title screen_daily_viz

# A single-day filter reuses tx_load, so sorting and name resolution behave
# exactly as on the month screen.
screen_daily_load() {
  tx_filter_clear; F_FROM=$DAY; F_TO=$DAY
  local f="$DATA/${DAY:0:7}.tsv"
  if [[ -f $f ]]; then tx_load "$f"; else TX=(); fi
  ROWS_DATA=("${TX[@]}"); SELECTABLE=1
}

screen_daily_row() { screen_row_tx "$1"; }

screen_daily_title() { screen_title_tx "Day: $DAY_LABEL"; }

screen_daily_viz() {
  local m=${DAY:0:7} r=$VY d nd se si mk ax
  pie_selected_category
  viz_spark_daily "$m" E; se=$SPK
  viz_spark_daily "$m" I; si=$SPK
  nd=${#se}; d=$((10#${DAY:8:2}))
  viz_section "$r" "Month at a glance"
  viz_line $((r + 1)) "${C_DIM}Exp  ${RST}${C_EXP}$se${RST}"
  viz_line $((r + 2)) "${C_DIM}Inc  ${RST}${C_INC}$si${RST}"
  # Marker under the sparkline column of the selected day.
  printf -v mk '%*s▲' $((d - 1)) ''
  viz_line $((r + 3)) "     ${C_ACC}$mk${RST}"
  printf -v ax '%s%*s' 1 $((nd - 1)) "$nd"
  viz_line $((r + 4)) "     ${C_DIM}$ax${RST}"
  r=$((r + 6))
  block_pies "$r" $((VY + VH - r)) TX " (day)"
}
