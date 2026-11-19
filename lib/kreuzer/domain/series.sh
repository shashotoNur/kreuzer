# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# domain/series.sh - time series rendered as unicode sparklines
#
# Depends on : data/store.sh, store_months
# Provides   : series_daily series_wallet_month series_wallet_year
# Out-vars   : SPK SMIN SMAX
#
# Each function returns a string of block characters (one per day or month) plus,
# for wallets, the minimum and maximum so the caller can label the scale.
# Callers cache the results; these functions always recompute.

# Per-day totals of one kind (I or E) for a month. A middle dot marks days with
# no activity so the string always has one character per day of the month.
series_daily() { # month kind -> SPK
  local f="$DATA/$1.tsv" nd; [[ -f $f ]] || f=/dev/null
  nd=$(date -d "$1-01 +1 month -1 day" +%d)
  SPK=$(awk -F'\t' -v nd=$((10#$nd)) -v k="$2" '
    $4==k { d=substr($2,9,2)+0; s[d]+=$5; if (s[d]>mx) mx=s[d] }
    END { split("▁ ▂ ▃ ▄ ▅ ▆ ▇ █", b, " "); o=""
      for (i=1;i<=nd;i++) { if (s[i]>0) { l=int(s[i]/mx*7+0.5)+1; o=o b[l] } else o=o "·" }
      print o }' "$f")
}

# Running balance of one wallet for each day of a month. The balance at the start
# of the month is the opening balance plus everything in earlier months.
series_wallet_month() { # wallet_id month -> SPK SMIN SMAX
  local -a mf; mapfile -t mf < <(store_months)
  local nd; nd=$(date -d "$2-01 +1 month -1 day" +%d)
  SPK=""; SMIN=0; SMAX=0
  read -r SPK SMIN SMAX < <(awk -F'\t' -v w="$1" -v m="$2" -v nd=$((10#$nd)) '
    FILENAME==ARGV[1] { if ($1==w) { bal=$3; od=$4; ok=1 } next }
    ok && $7==w && $2>=od { d=$5; if ($4=="E"||$4=="TO") d=-d; mo=substr($2,1,7)
      if (mo<m) start+=d; else if (mo==m) day[substr($2,9,2)+0]+=d }
    END { cur=bal+start; split("▁ ▂ ▃ ▄ ▅ ▆ ▇ █", b, " "); mn=cur; mx=cur
      for (i=1;i<=nd;i++) { cur+=day[i]; v[i]=cur; if (cur<mn) mn=cur; if (cur>mx) mx=cur }
      o=""; for (i=1;i<=nd;i++) { l=(mx>mn)? int((v[i]-mn)/(mx-mn)*7+0.5)+1 : 4; o=o b[l] }
      print o, mn, mx }' "$WALS" "${mf[@]}")
}

# Month-end balances for the 12 months ending at MONTH. The month arithmetic is
# done in awk by hand (no date calls) so it stays a single process.
series_wallet_year() { # wallet_id month -> SPK SMIN SMAX
  local -a mf; mapfile -t mf < <(store_months)
  SPK=""; SMIN=0; SMAX=0
  read -r SPK SMIN SMAX < <(awk -F'\t' -v w="$1" -v m="$2" '
    FILENAME==ARGV[1] { if ($1==w) { bal=$3; od=$4; ok=1 } next }
    ok && $7==w && $2>=od { d=$5; if ($4=="E"||$4=="TO") d=-d; s[substr($2,1,7)]+=d }
    END {
      y=substr(m,1,4)+0; mo=substr(m,6,2)+0; m0=mo-11; y0=y
      while (m0<1) { m0+=12; y0-- }
      first=sprintf("%04d-%02d", y0, m0); cur=bal
      for (k in s) if (k<first) cur+=s[k]
      yy=y0; mm=m0
      for (i=1;i<=12;i++) {
        k=sprintf("%04d-%02d", yy, mm); cur+=s[k]; v[i]=cur
        if (i==1||cur<mn) mn=cur
        if (i==1||cur>mx) mx=cur
        mm++; if (mm>12) { mm=1; yy++ }
      }
      split("▁ ▂ ▃ ▄ ▅ ▆ ▇ █", b, " "); o=""
      for (i=1;i<=12;i++) { l=(mx>mn)? int((v[i]-mn)/(mx-mn)*7+0.5)+1 : 4; o=o b[l] }
      print o, mn, mx
    }' "$WALS" "${mf[@]}")
}
