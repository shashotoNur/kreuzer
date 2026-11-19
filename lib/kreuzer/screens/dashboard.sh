# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# screens/dashboard.sh - month overview: totals, budget, quota alerts, wallets
#
# Depends on : domain/*, viz/*, screens/common.sh
# Provides   : screen_dashboard_load screen_dashboard_row screen_dashboard_title screen_dashboard_viz
#
# Not selectable: rows are preformatted text lines, so screen_dashboard_row passes
# them through.

screen_dashboard_load() {
  tx_load_month; totals_load_categories "$MONTH"; totals_month "$MONTH"; budget_for_month "$MONTH"
  SELECTABLE=0; ROWS_DATA=()
  local line id kd nm sp q nc=$C_INC b1 any=0 bnote lo up
  money_format "$INC"; ROWS_DATA+=("${C_DIM}Income      ${RST}${C_INC}+$M${RST}")
  money_format "$EXP"; ROWS_DATA+=("${C_DIM}Expenses    ${RST}${C_EXP}-$M${RST}")
  ((INC < EXP)) && nc=$C_EXP
  money_format $((INC - EXP)); ROWS_DATA+=("${C_DIM}Net         ${RST}${nc}$M${RST}")
  if ((BUD > 0)); then
    money_format "$BUD"; b1=$M
    if ((EXP <= BUD)); then money_format $((BUD - EXP)); ROWS_DATA+=("${C_DIM}Budget      ${RST}${C_TXT}$b1${RST}  ${C_OK}unused $M${RST}")
    else money_format $((EXP - BUD)); ROWS_DATA+=("${C_DIM}Budget      ${RST}${C_TXT}$b1${RST}  ${C_BAD}over by $M${RST}"); fi
  else ROWS_DATA+=("${C_DIM}Budget      not set (open Budget screen)${RST}"); fi
  ROWS_DATA+=("")
  for line in "${CS[@]}"; do
    IFS=$'\t' read -r id kd nm sp q <<<"$line"
    if [[ $kd == E ]] && ((q > 0 && sp > q)); then
      ((any)) || { ROWS_DATA+=("${BOLD}${C_ACC}Quota alerts${RST}"); any=1; }
      money_format $((sp - q)); ROWS_DATA+=("  ${C_WARN}$nm${RST} ${C_DIM}is over quota by${RST} ${C_BAD}$M${RST}")
    fi
  done
  ((any)) && ROWS_DATA+=("")
  ROWS_DATA+=("${BOLD}${C_ACC}Wallets${RST}")
  for line in "${WB[@]}"; do
    IFS=$'\t' read -r id nm sp lo up <<<"$line"
    bnote=""
    [[ $lo != - ]] && ((sp <= lo)) && bnote="  ${C_WARN}at/below lower bound${RST}"
    [[ $up != - ]] && ((sp >= up)) && bnote="  ${C_OK}upper bound reached${RST}"
    text_pad "$nm" 16; money_format "$sp"; text_rpad "$M" 14
    ROWS_DATA+=("  ${C_TXT}$PAD${RST}${C_ACC}$RP${RST}$bnote")
  done
  ((${#WB[@]})) || ROWS_DATA+=("  ${C_DIM}no wallets yet${RST}")
}

screen_dashboard_row() { RR=$1; }

screen_dashboard_title() { TL="Overview - $MONTH_LABEL"; }

screen_dashboard_viz() {
  local r=$VY each bh=4 left
  LEG_HL=""
  totals_quota_sum CS
  ((BUD > 0 && QS > BUD)) && bh=5
  # Drop the budget block on short terminals so the pies keep their size.
  ((VH - bh < 12)) && bh=0
  each=$(((VH - bh) / 2))
  pie_aggregate tx I TX; pie_slices
  if pie_panel "$r" "$VX" "$VW" "$each" "Income" "+" "$C_INC"; then r=$((r + USED)); fi
  pie_aggregate tx E TX; pie_slices
  if pie_panel "$r" "$VX" "$VW" "$each" "Expenses" "-" "$C_EXP"; then r=$((r + USED)); fi
  if ((bh)); then block_budget "$r" "$EXP" "$BUD" "$QS"; r=$((r + USED + 1)); fi
  left=$((VY + VH - r))
  if ((left >= 3 && ${#WB[@]} > 0)); then viz_section "$r" "Wallets"; block_wallets $((r + 1)) $((left - 1)); fi
}
