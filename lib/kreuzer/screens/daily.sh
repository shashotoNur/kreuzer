# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# screens/daily.sh - one day: its transactions, pies and a month-at-a-glance strip
#
# Depends on : data/transactions.sh, domain/series.sh, viz/*, screens/common.sh
# Provides   : load_daily row_daily title_daily viz_daily

# A single-day filter reuses load_tx, so sorting and name resolution behave
# exactly as on the month screen.
load_daily() {
  clear_filter; F_FROM=$DAY; F_TO=$DAY
  local f="$DATA/${DAY:0:7}.tsv"
  if [[ -f $f ]]; then load_tx "$f"; else TX=(); fi
  ROWS_DATA=("${TX[@]}"); SELECTABLE=1
}

row_daily() { row_tx "$1"; }

title_daily() { title_tx "Day: $DAY_LABEL"; }

viz_daily() {
  local m=${DAY:0:7} r=$VY d nd se si mk ax
  sel_cat
  spark_c "$m" E; se=$SPK
  spark_c "$m" I; si=$SPK
  nd=${#se}; d=$((10#${DAY:8:2}))
  sec "$r" "Month at a glance"
  vp $((r + 1)) "${C_DIM}Exp  ${RST}${C_EXP}$se${RST}"
  vp $((r + 2)) "${C_DIM}Inc  ${RST}${C_INC}$si${RST}"
  # Marker under the sparkline column of the selected day.
  printf -v mk '%*s▲' $((d - 1)) ''
  vp $((r + 3)) "     ${C_ACC}$mk${RST}"
  printf -v ax '%s%*s' 1 $((nd - 1)) "$nd"
  vp $((r + 4)) "     ${C_DIM}$ax${RST}"
  r=$((r + 6))
  viz_pair "$r" $((VY + VH - r)) TX " (day)"
}
