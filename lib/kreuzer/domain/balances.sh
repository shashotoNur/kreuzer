# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# domain/balances.sh - wallet balances and net worth
#
# Depends on : data/store.sh, money_format
# Provides   : balances_load balances_get balances_name
# Globals    : WB NW NW_TXT WMAX
# Out-vars   : WBN WBB WBL WBU WNM
#
# meta/wallets.tsv columns: id, name, opening_cents, opening_date, lower, upper, sort_order
# WB rows: id, name, balance, lower, upper (sorted by sort_order)

# Balance = opening balance plus every movement on or after the opening date,
# across all month files, computed in one awk pass. Nothing is cached on disk, so
# the files stay the single source of truth.
# Transfers need no special case: the TO and TI legs are ordinary signed rows, so
# they cancel out in net worth by themselves.
balances_load() {
  local -a mf; mapfile -t mf < <(store_months)
  mapfile -t WB < <(awk -F'\t' -v OFS='\t' '
    FILENAME==ARGV[1] { if ($1=="") next; name[$1]=$2; bal[$1]=$3; od[$1]=$4; lo[$1]=$5; up[$1]=$6; so[$1]=$7; next }
    { w=$7; if (!(w in name)) next; if ($2 < od[w]) next; d=$5; if ($4=="E"||$4=="TO") d=-d; bal[w]+=d }
    END { for (w in name) print so[w], w, name[w], bal[w], lo[w], up[w] }' "$WALS" "${mf[@]}" |
    sort -t$'\t' -k1,1n -k2,2n | cut -f2-)
  NW=0; WMAX=1
  local line id nm b lo up
  for line in "${WB[@]}"; do
    IFS=$'\t' read -r id nm b lo up <<<"$line"
    NW=$((NW + b)); ((b > WMAX)) && WMAX=$b
  done
  money_format "$NW"; NW_TXT=$M
}

# balances_get ID -> WBN WBB WBL WBU (name, balance, lower, upper); status 1 if unknown.
balances_get() {
  local l id
  for l in "${WB[@]}"; do
    IFS=$'\t' read -r id WBN WBB WBL WBU <<<"$l"
    [[ $id == "$1" ]] && return 0
  done
  WBN=""; return 1
}

# balances_name ID -> WNM (wallet name only)
balances_name() {
  local l id x; WNM=""
  for l in "${WB[@]}"; do
    IFS=$'\t' read -r id x _ <<<"$l"
    [[ $id == "$1" ]] && { WNM=$x; return 0; }
  done
  return 1
}
