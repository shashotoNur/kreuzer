# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# screens/categories.sh - categories with this month's total, quota and usage
#
# Depends on : domain/totals.sh (load_cs), viz/*, config/keys.sh (KEYDEF for hints)
# Provides   : load_categories row_categories title_categories viz_categories
#
# CS rows: id, kind, name, spent, quota

load_categories() {
  load_month_tx; load_cs "$MONTH"; SELECTABLE=1
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

row_categories() {
  local id kd nm sp q mk col np s1 q1 bw st=""
  IFS=$'\t' read -r id kd nm sp q <<<"$1"
  if [[ $kd == I ]]; then mk="+"; col=$C_INC; else mk="-"; col=$C_EXP; fi
  pad "$nm" 18; np=$PAD
  fm "$sp"; rpad "$M" 13; s1=$RP
  if [[ $kd == E ]] && ((q > 0)); then
    fm "$q"; rpad "$M" 13; q1=$RP
    bw=$((LW - 48)); ((bw > 20)) && bw=20
    if ((bw >= 4)); then mkbar "$sp" "$q" "$bw"; st=$BAR; fi
  else rpad "-" 13; q1=$RP; fi
  RR="${col}${mk}${RST} ${C_TXT}$np${RST}${col}$s1${RST} ${C_DIM}$q1${RST} $st"
}

title_categories() {
  local dir="↑"; ((CATREV)) && dir="↓"
  TL="Categories - $MONTH_LABEL - sort: $CATSORT $dir"
  printf -v CH '%-2s%-18s%13s %13s %s' "" Name "This month" Quota Usage
}

viz_categories() {
  local r=$VY n=${#ROWS_DATA[@]} id kd nm sp q each ttl sg tc a b cap
  LEG_HL=""
  if ((n == 0)); then sec "$r" "Categories"; vp $((r + 1)) "${C_DIM}No categories yet.${RST}"; return 0; fi
  IFS=$'\t' read -r id kd nm sp q <<<"${ROWS_DATA[SEL]}"; LEG_HL=$nm
  if [[ $kd == I ]]; then ttl="Income by category"; sg="+"; tc=$C_INC
  else ttl="Expenses by category"; sg="-"; tc=$C_EXP; fi
  each=$((VH * 45 / 100)); ((each < 7)) && each=7; ((each > VH - 6)) && each=$((VH - 6))
  agg cs "$kd" CS; make_slices
  if pie_panel "$r" "$VX" "$VW" "$each" "$ttl" "$sg" "$tc"; then r=$((r + USED)); fi
  cap=$((VY + VH - r - 4))
  if ((cap >= 2)); then quota_lines "$r" "$cap" ROWS_DATA "$id" 0 "Quota usage"; r=$((r + USED + 1)); fi
  if [[ $kd == E ]]; then
    if ((q > 0)); then
      fm "$sp"; a=$M; fm "$q"; b=$M
      vp "$r" "${C_TXT}$nm${RST} ${C_DIM}spent${RST} ${C_TXT}$a${RST} ${C_DIM}of${RST} ${C_TXT}$b${RST}"
      if ((sp <= q)); then fm $((q - sp)); vp $((r + 1)) "${C_OK}$M left in quota${RST}"
      else fm $((sp - q)); vp $((r + 1)) "${C_BAD}over quota by $M${RST}"; fi
    else
      kn "${KEYDEF[edit]%%,*}"
      vp "$r" "${C_TXT}$nm${RST} ${C_DIM}has no quota. Press${RST} ${C_ACC}$KN${RST} ${C_DIM}to set one.${RST}"
    fi
  else
    fm "$sp"; vp "$r" "${C_TXT}$nm${RST} ${C_DIM}this month${RST} ${C_INC}+$M${RST}"
  fi
}
