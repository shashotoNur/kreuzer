# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# data/transactions.sh - month files: filtering, sorting, search queries
#
# Depends on : data/store.sh, parse_date, parse_money, CATS, WALS
# Provides   : clear_filter parse_query load_tx load_month_tx
# Globals    : F_FROM F_TO F_MIN F_MAX F_TEXT F_RE  (filter, set by parse_query)
#
# meta month file (YYYY-MM.tsv) columns:
#   id, date, time, kind (I E TO TI), cents, category_id, wallet_id, transfer_id, note
# load_tx output rows (what the screens consume):
#   id, "date time", kind, cents, category, wallet, note, transfer_id, category_id, wallet_id

clear_filter() { F_FROM=; F_TO=; F_MIN=; F_MAX=; F_TEXT=; F_RE=0; }

# Query syntax: free words plus from:DD/MM/YYYY to:DD/MM/YYYY min:12.50 max:99.
# A word wrapped in slashes (/rent|food/) switches to regular-expression matching.
# Tokens with an invalid value are treated as ordinary text rather than rejected,
# so a half-typed filter does not blank the result list.
parse_query() {
  local q=$1 tok words=""
  clear_filter
  for tok in $q; do
    case $tok in
      from:*) parse_date "${tok#from:}" && F_FROM=$PD ;;
      to:*)   parse_date "${tok#to:}" && F_TO=$PD ;;
      min:*)  parse_money "${tok#min:}" && F_MIN=$PM ;;
      max:*)  parse_money "${tok#max:}" && F_MAX=$PM ;;
      *) words+="${words:+ }$tok" ;;
    esac
  done
  if [[ $words == /*/ && ${#words} -gt 2 ]]; then F_RE=1; F_TEXT=${words:1:${#words}-2}
  else F_TEXT=$words; fi
}

# load_tx FILE... -> TX, filtered by F_* and sorted by TXSORT/TXREV.
# Names are resolved here, not stored in the month files, so a category rename
# applies to old transactions, and ids missing from the lookup tables show as
# DELETED. That is also what makes trash restore re-link everything for free.
# The search text goes through the environment to avoid shell quoting problems
# with arbitrary user input.
load_tx() {
  local skey
  case $TXSORT in
    amount) skey="4,4n" ;; category) skey="5,5f" ;; wallet) skey="6,6f" ;; type) skey="3,3" ;; *) skey="2,2" ;;
  esac
  ((TXREV)) && skey+="r"
  mapfile -t TX < <(TXT="$F_TEXT" awk -F'\t' -v OFS='\t' -v from="$F_FROM" -v to="$F_TO" \
    -v mn="$F_MIN" -v mx="$F_MAX" -v re="$F_RE" -v cf="$CATS" -v wf="$WALS" '
    BEGIN {
      while ((getline l < cf) > 0) { split(l, a, "\t"); cn[a[1]] = a[3] }
      while ((getline l < wf) > 0) { split(l, a, "\t"); wn[a[1]] = a[2] }
      txt = tolower(ENVIRON["TXT"])
    }
    {
      if ($1 == "") next
      c = ($6 == "-") ? "Transfer" : (($6 in cn) ? cn[$6] : "DELETED")
      w = ($7 in wn) ? wn[$7] : "DELETED"
      if (from != "" && $2 < from) next
      if (to != "" && $2 > to) next
      if (mn != "" && $5 + 0 < mn + 0) next
      if (mx != "" && $5 + 0 > mx + 0) next
      if (txt != "") {
        h = tolower(c " " w " " (($9 == "-") ? "" : $9))
        if (re == 1) { if (h !~ txt) next } else if (index(h, txt) == 0) next
      }
      print $1, $2 " " $3, $4, $5, c, w, $9, $8, $6, $7
    }' "$@" | sort -t$'\t' -k"$skey" -k1,1n)
}

load_month_tx() {
  clear_filter
  local f="$DATA/$MONTH.tsv"
  if [[ -f $f ]]; then load_tx "$f"; else TX=(); fi
}
