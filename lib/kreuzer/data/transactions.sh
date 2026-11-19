# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# data/transactions.sh - month files: filtering, sorting, search queries
#
# Depends on : data/store.sh, date_parse, money_parse, CATS, WALS
# Provides   : tx_filter_clear tx_parse_query tx_load tx_load_month tx_save tx_save_transfer tx_transfer_parts
# Globals    : F_FROM F_TO F_MIN F_MAX F_TEXT F_RE  (filter, set by tx_parse_query)
#
# meta month file (YYYY-MM.tsv) columns:
#   id, date, time, kind (I E TO TI), cents, category_id, wallet_id, transfer_id, note
# tx_load output rows (what the screens consume):
#   id, "date time", kind, cents, category, wallet, note, transfer_id, category_id, wallet_id

tx_filter_clear() { F_FROM=; F_TO=; F_MIN=; F_MAX=; F_TEXT=; F_RE=0; }

# Query syntax: free words plus from:DD/MM/YYYY to:DD/MM/YYYY min:12.50 max:99.
# A word wrapped in slashes (/rent|food/) switches to regular-expression matching.
# Tokens with an invalid value are treated as ordinary text rather than rejected,
# so a half-typed filter does not blank the result list.
tx_parse_query() {
  local q=$1 tok words=""
  tx_filter_clear
  for tok in $q; do
    case $tok in
      from:*) date_parse "${tok#from:}" && F_FROM=$PD ;;
      to:*)   date_parse "${tok#to:}" && F_TO=$PD ;;
      min:*)  money_parse "${tok#min:}" && F_MIN=$PM ;;
      max:*)  money_parse "${tok#max:}" && F_MAX=$PM ;;
      *) words+="${words:+ }$tok" ;;
    esac
  done
  if [[ $words == /*/ && ${#words} -gt 2 ]]; then F_RE=1; F_TEXT=${words:1:${#words}-2}
  else F_TEXT=$words; fi
}

# tx_load FILE... -> TX, filtered by F_* and sorted by TXSORT/TXREV.
# Names are resolved here, not stored in the month files, so a category rename
# applies to old transactions, and ids missing from the lookup tables show as
# DELETED. That is also what makes trash restore re-link everything for free.
# The search text goes through the environment to avoid shell quoting problems
# with arbitrary user input.
tx_load() {
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

tx_load_month() {
  tx_filter_clear
  local f="$DATA/$MONTH.tsv"
  if [[ -f $f ]]; then tx_load "$f"; else TX=(); fi
}


# ------------------------------------------------------------------ writers
# Values arrive validated. Empty time and note must be passed as "-", because
# `read` with a tab separator collapses empty fields and shifts later columns.

# tx_save ID OLD_DATE DATE TIME KIND CENTS CATEGORY WALLET NOTE
# An empty ID creates a row. Editing removes the old row, then appends the new
# one, so a changed date moves the entry to the right month file for free.
tx_save() {
  local id=$1
  if [[ -n $id ]]; then store_row_remove "$DATA/${2:0:7}.tsv" "$id"; else store_next_id; id=$NID; fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t-\t%s\n' "$id" "$3" "$4" "$5" "$6" "$7" "$8" "$9" >>"$DATA/${3:0:7}.tsv"
}

# tx_save_transfer TID OLD_DATE DATE TIME AMOUNT FROM TO FEE NOTE -> FEEC
# An empty TID creates a transfer. Editing drops the whole old set (TO, TI and
# fee rows) and writes a new one under the same id. FEEC is set only when a fee
# row was written, so callers can pass it on to the alert check.
tx_save_transfer() {
  local tid=$1 old=$2 d=$3 t=$4 amt=$5 from=$6 to=$7 fee=$8 note=$9 f
  FEEC=""
  if [[ -n $tid ]]; then
    f="$DATA/${old:0:7}.tsv"; awk -F'\t' -v t="$tid" '$8!=t' "$f" | store_atomic "$f"
  else store_next_id; tid=$NID; fi
  f="$DATA/${d:0:7}.tsv"
  store_next_id; printf '%s\t%s\t%s\tTO\t%s\t-\t%s\t%s\t%s\n' "$NID" "$d" "$t" "$amt" "$from" "$tid" "$note" >>"$f"
  store_next_id; printf '%s\t%s\t%s\tTI\t%s\t-\t%s\t%s\t%s\n' "$NID" "$d" "$t" "$amt" "$to" "$tid" "$note" >>"$f"
  if ((fee > 0)); then
    category_ensure_fee; store_next_id
    printf '%s\t%s\t%s\tE\t%s\t%s\t%s\t%s\t-\n' "$NID" "$d" "$t" "$fee" "$FEEC" "$from" "$tid" >>"$f"
  fi
}

# tx_transfer_parts TID DATE -> TP_FROM TP_TO TP_AMT TP_FEE TP_NOTE
# Rebuilds a transfer from all its rows, whichever row the user selected.
tx_transfer_parts() {
  local r1 r2 r3 r4 r5 r6 r7 r8 r9
  TP_FROM=""; TP_TO=""; TP_AMT=0; TP_FEE=0; TP_NOTE="-"
  while IFS=$'\t' read -r r1 r2 r3 r4 r5 r6 r7 r8 r9; do
    case $r4 in TO) TP_FROM=$r7; TP_AMT=$r5; TP_NOTE=$r9 ;; TI) TP_TO=$r7 ;; E) TP_FEE=$r5 ;; esac
  done < <(awk -F'\t' -v t="$1" '$8==t' "$DATA/${2:0:7}.tsv")
}
