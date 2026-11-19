# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# domain/totals.sh - monthly totals and per-category spending against quotas
#
# Depends on : data/store.sh, data/budget.sh
# Provides   : load_cs month_totals quota_sum
# Globals    : CS
# Out-vars   : INC EXP QS
#
# CS rows: id, kind, name, spent, quota (sorted by sort_order)
# Only I and E rows count here. Transfer legs and transfer fees are separate
# kinds or categories, so moving money between wallets never inflates income
# or expenses.

load_cs() { # month -> CS
  local f="$DATA/$1.tsv"; [[ -f $f ]] || f=/dev/null
  mapfile -t CS < <(awk -F'\t' -v OFS='\t' -v m="$1" '
    FILENAME==ARGV[1] { if ($1=="") next; kind[$1]=$2; nm[$1]=$3; so[$1]=$4; next }
    FILENAME==ARGV[2] { if ($1<=m && (!($2 in qe) || $1>=qe[$2])) { qe[$2]=$1; q[$2]=$3 } next }
    ($4=="I" || $4=="E") { s[$6]+=$5 }
    END { for (c in kind) print so[c], c, kind[c], nm[c], s[c]+0, q[c]+0 }' "$CATS" "$QUOTAS" "$f" |
    sort -t$'\t' -k1,1n -k2,2n | cut -f2-)
}

month_totals() { # month -> INC EXP
  local f="$DATA/$1.tsv"; INC=0; EXP=0
  [[ -f $f ]] || return 0
  read -r INC EXP < <(awk -F'\t' '$4=="I"{i+=$5} $4=="E"{e+=$5} END{print i+0, e+0}' "$f")
}

# quota_sum ARRAYNAME -> QS : total of expense quotas in a CS-shaped array.
# Takes the array by name so previews can pass their own copy without touching CS.
quota_sum() {
  local -n _q=$1; local l id kd nm sp q
  QS=0
  for l in "${_q[@]}"; do
    IFS=$'\t' read -r id kd nm sp q <<<"$l"
    [[ $kd == E ]] && QS=$((QS + q))
  done
}
