# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# screens/categories.sh - categories with this month's total, quota and usage
#
# Depends on : domain/totals.sh (totals_load_categories), viz/*, config/keys.sh (KEYDEF for hints)
# Provides   : screen_categories_load screen_categories_row screen_categories_title screen_categories_viz
#
# CS rows: id, kind, name, spent, quota

screen_categories_load() {
  tx_load_month; totals_load_categories "$MONTH"; SELECTABLE=1
  local sk=""
  case $CATSORT in name) sk="3,3f" ;; total) sk="4,4n" ;; kind) sk="2,2" ;; esac
  ROWS_DATA=("${CS[@]}")
  ((${#CS[@]})) || return 0
  # "manual" keeps the stored order (CS arrives sorted by sort_order); only
  # reversing needs work. The id is the tie-breaker, so equal keys stay stable.
  if [[ -n $sk ]]; then
    ((CATREV)) && sk+="r"
    mapfile -t ROWS_DATA < <(printf '%s\n' "${CS[@]}" | sort -t$'\t' -k"$sk" -k1,1n)
  elif ((CATREV)); then
    mapfile -t ROWS_DATA < <(printf '%s\n' "${CS[@]}" | tac)
  fi
}

screen_categories_row() {
  local id kd nm sp q mk col np s1 q1 bw st=""
  IFS=$'\t' read -r id kd nm sp q <<<"$1"
  if [[ $kd == I ]]; then mk="+"; col=$C_INC; else mk="-"; col=$C_EXP; fi
  text_pad "$nm" 18; np=$PAD
  money_format "$sp"; text_rpad "$M" 13; s1=$RP
  if [[ $kd == E ]] && ((q > 0)); then
    money_format "$q"; text_rpad "$M" 13; q1=$RP
    bw=$((LW - 48)); ((bw > 20)) && bw=20
    if ((bw >= 4)); then viz_bar "$sp" "$q" "$bw"; st=$BAR; fi
  else text_rpad "-" 13; q1=$RP; fi
  RR="${col}${mk}${RST} ${C_TXT}$np${RST}${col}$s1${RST} ${C_DIM}$q1${RST} $st"
}

screen_categories_title() {
  local dir="↑"; ((CATREV)) && dir="↓"
  TL="Categories - $MONTH_LABEL - sort: $CATSORT $dir"
  printf -v CH '%-2s%-18s%13s %13s %s' "" Name "This month" Quota Usage
}

screen_categories_viz() {
  local r=$VY n=${#ROWS_DATA[@]} id kd nm sp q each ttl sg tc a b cap
  LEG_HL=""
  if ((n == 0)); then viz_section "$r" "Categories"; viz_line $((r + 1)) "${C_DIM}No categories yet.${RST}"; return 0; fi
  IFS=$'\t' read -r id kd nm sp q <<<"${ROWS_DATA[SEL]}"; LEG_HL=$nm
  if [[ $kd == I ]]; then ttl="Income by category"; sg="+"; tc=$C_INC
  else ttl="Expenses by category"; sg="-"; tc=$C_EXP; fi
  each=$((VH * 45 / 100)); ((each < 7)) && each=7; ((each > VH - 6)) && each=$((VH - 6))
  pie_aggregate cs "$kd" CS; pie_slices
  if pie_panel "$r" "$VX" "$VW" "$each" "$ttl" "$sg" "$tc"; then r=$((r + USED)); fi
  cap=$((VY + VH - r - 4))
  if ((cap >= 2)); then block_quotas "$r" "$cap" ROWS_DATA "$id" 0 "Quota cli_usage"; r=$((r + USED + 1)); fi
  if [[ $kd == E ]]; then
    if ((q > 0)); then
      money_format "$sp"; a=$M; money_format "$q"; b=$M
      viz_line "$r" "${C_TXT}$nm${RST} ${C_DIM}spent${RST} ${C_TXT}$a${RST} ${C_DIM}of${RST} ${C_TXT}$b${RST}"
      if ((sp <= q)); then money_format $((q - sp)); viz_line $((r + 1)) "${C_OK}$M left in quota${RST}"
      else money_format $((sp - q)); viz_line $((r + 1)) "${C_BAD}over quota by $M${RST}"; fi
    else
      input_key_label "${KEYDEF[edit]%%,*}"
      viz_line "$r" "${C_TXT}$nm${RST} ${C_DIM}has no quota. Press${RST} ${C_ACC}$KN${RST} ${C_DIM}to set one.${RST}"
    fi
  else
    money_format "$sp"; viz_line "$r" "${C_TXT}$nm${RST} ${C_DIM}this month${RST} ${C_INC}+$M${RST}"
  fi
}
