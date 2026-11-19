# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# forms/budget.sh - set the monthly budget
#
# Depends on : ui/form.sh, data/budget.sh, viz/blocks.sh (qsum_month), domain/alerts.sh
# Provides   : budget_form pv_budget
#
# The value applies from the chosen month on; earlier months keep theirs, so
# their unused/overused figures stay accurate.

pv_budget() {
  local m b=0
  printf -v m '%(%Y-%m)T' -1; PVL=()
  qsum_month "$m"; fm "$QS"
  PVL+=("${C_DIM}Category quotas total $M for $m.${RST}")
  if [[ -n ${FV[0]} ]] && parse_money "${FV[0]}"; then b=$PM; fi
  ((b > 0 && QS > b)) && PVL+=("${C_WARN}The quotas exceed this budget.${RST}")
  return 0
}

budget_form() {
  local m cur vb="" newb bm
  printf -v m '%(%Y-%m)T' -1; budget_for "$m"; cur=$BUD
  if ((cur > 0)); then plain "$cur"; vb=${PL/./$DEC}; fi
  form_begin "Monthly budget" pv_budget "" ""
  form_field Budget omoney "$vb" "Total mandatory expense budget. Empty removes it."
  form_field "From" date "01/${m:5:2}/${m:0:4}" "Applies from this month on. Earlier months keep their value."
  if run_form; then
    newb=0; if [[ -n ${FV[0]} ]]; then parse_money "${FV[0]}"; newb=$PM; fi
    parse_date "${FV[1]}"; bm=${PD:0:7}
    if ((cur > 0 && newb != cur)) && ! confirm "Changing the budget is discouraged: it blurs month comparisons. Change anyway?"; then
      flash "$C_WARN" "Budget left unchanged."; refresh; return 0
    fi
    # One record per effective month: replace, never append duplicates.
    awk -F'\t' -v m="$bm" '$1!=m' "$BUDG" | atomic "$BUDG"
    printf '%s\t%s\n' "$bm" "$newb" >>"$BUDG"
    ALERTS=(); qb_alert "$bm"
    flash "$C_OK" "Saved."; refresh; show_alerts
  else draw; fi
}
