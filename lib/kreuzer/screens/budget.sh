# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# screens/budget.sh - budget history: budget versus spending for every month
#
# Depends on : data/budget.sh, domain/totals.sh, viz/*
# Provides   : load_budget row_budget title_budget viz_budget
#
# Raw rows: month, budget, spent, income. Months come from data files, from the
# budget records and from the viewed month, so a month with a budget but no
# transactions (and the current month) still shows up.

load_budget() {
  local -a mf ms=(); local f b m
  mapfile -t mf < <(all_months)
  for f in "${mf[@]}"; do b=${f##*/}; ms+=("${b%.tsv}"); done
  ms+=("$MONTH")
  while IFS= read -r b; do ms+=("$b"); done < <(cut -f1 "$BUDG")
  mapfile -t ms < <(printf '%s\n' "${ms[@]}" | sort -ur)
  ROWS_DATA=(); SELECTABLE=1; TX=()
  for m in "${ms[@]}"; do
    [[ -n $m ]] || continue
    month_totals "$m"; budget_for "$m"
    ROWS_DATA+=("$m"$'\t'"$BUD"$'\t'"$EXP"$'\t'"$INC")
  done
}

row_budget() {
  local m bud ex inc mp b1 e1 d=""
  IFS=$'\t' read -r m bud ex inc <<<"$1"
  pad "$m" 9; mp=$PAD
  if ((bud > 0)); then fm "$bud"; rpad "$M" 14; else rpad "-" 14; fi; b1=$RP
  fm "$ex"; rpad "$M" 14; e1=$RP
  if ((bud > 0)); then
    if ((ex <= bud)); then fm $((bud - ex)); d="${C_OK}unused $M${RST}"
    else fm $((ex - bud)); d="${C_BAD}over $M${RST}"; fi
  fi
  RR="${C_TXT}$mp${RST}${C_DIM}$b1${RST}${C_TXT}$e1${RST}  $d"
}

title_budget() {
  TL="Monthly budget history"
  printf -v CH '%-9s%14s%14s  %s' Month Budget Spent "Unused / over"
}

viz_budget() {
  local r=$VY n=${#ROWS_DATA[@]} m bud ex inc i start cap bw pc pcs mk nc mxe=0 l a1 a2 a3 a4
  if ((n == 0)); then sec "$r" "Budget"; vp $((r + 1)) "${C_DIM}No history yet.${RST}"; return 0; fi
  IFS=$'\t' read -r m bud ex inc <<<"${ROWS_DATA[SEL]}"
  qsum_month "$m"
  budget_block "$r" "$ex" "$bud" "$QS" "Budget $m"; r=$((r + USED + 1))
  for l in "${ROWS_DATA[@]}"; do IFS=$'\t' read -r a1 a2 a3 a4 <<<"$l"; ((a3 > mxe)) && mxe=$a3; done
  cap=$((VY + VH - r - 1)); ((cap >= 1)) || return 0
  sec "$r" "Spent vs budget"; r=$((r + 1))
  ((cap > n)) && cap=$n
  start=$((SEL - cap / 2)); ((start > n - cap)) && start=$((n - cap)); ((start < 0)) && start=0
  bw=$((VW - 15)); ((bw < 6)) && bw=6
  for ((i = start; i < start + cap; i++)); do
    IFS=$'\t' read -r a1 a2 a3 a4 <<<"${ROWS_DATA[i]}"
    mk=" "; nc=$C_TXT
    if ((i == SEL)); then mk="${C_ACC}›${RST}"; nc=$BOLD$C_TXT; fi
    # Months without a budget fall back to a neutral bar scaled to the largest spend.
    if ((a2 > 0)); then mkbar "$a3" "$a2" "$bw"; pc=$((a3 * 100 / a2)); printf -v pcs '%4d%%' "$pc"
    else nbar "$a3" "$mxe" "$bw"; pcs="    -"; fi
    vp $((r + i - start)) "$mk${nc}$a1${RST} $BAR ${C_DIM}$pcs${RST}"
  done
}
