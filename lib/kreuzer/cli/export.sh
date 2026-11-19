# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# cli/export.sh - print one month as CSV
#
# Depends on : data/store.sh paths (store_set_paths), log_die
# Provides   : cli_export

# Names are resolved from the id tables, like in the app, so exports match what
# the screens show (including DELETED). Expenses and outgoing transfers are
# negative so the sign alone tells the direction. Text fields are quoted with
# doubled quotes, the CSV rule, since notes may contain commas.
cli_export() { # YYYY-MM
  local f="$DATA/$1.tsv"
  [[ $1 =~ ^[0-9]{4}-[0-9]{2}$ ]] || log_die "month must look like 2026-11"
  [[ -f $f ]] || log_die "no data file for $1"
  awk -F'\t' -v cf="$CATS" -v wf="$WALS" '
    function q(s) { gsub(/"/, "\"\"", s); return "\"" s "\"" }
    BEGIN {
      while ((getline l < cf) > 0) { split(l, a, "\t"); cn[a[1]] = a[3] }
      while ((getline l < wf) > 0) { split(l, a, "\t"); wn[a[1]] = a[2] }
      print "date,time,type,amount,category,wallet,note"
    }
    $1 != "" {
      t = ($4=="I") ? "income" : ($4=="E") ? "expense" : ($4=="TO") ? "transfer out" : "transfer in"
      s = ($4=="E" || $4=="TO") ? -$5 : $5
      c = ($6=="-") ? "" : (($6 in cn) ? cn[$6] : "DELETED")
      w = ($7 in wn) ? wn[$7] : "DELETED"
      printf "%s/%s/%s,%s,%s,%.2f,%s,%s,%s\n", substr($2,9,2), substr($2,6,2), substr($2,1,4), ($3=="-") ? "" : $3, t, s/100, q(c), q(w), q(($9=="-") ? "" : $9)
    }' "$f"
}
