# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# forms/wallet.sh - add or edit a wallet with opening balance and bounds
#
# Depends on : ui/form.sh, data/store.sh
# Provides   : wallet_form vd_wallet
# Globals    : WF_ID
#
# meta/wallets.tsv columns: id, name, opening_cents, opening_date, lower, upper, sort_order
# "-" stands for "no bound".

WF_ID=""

vd_wallet() {
  local lo up
  if awk -F'\t' -v n="${FV[0],,}" -v i="$WF_ID" 'tolower($2)==n && $1!=i{f=1} END{exit !f}' "$WALS"; then
    FERR="a wallet with that name already exists"; return 1
  fi
  if [[ -n ${FV[3]} && -n ${FV[4]} ]]; then
    scents "${FV[3]}"; lo=$PM; scents "${FV[4]}"; up=$PM
    ((up > lo)) || { FERR="the upper bound must be above the lower bound"; return 1; }
  fi
}

wallet_form() { # [row]
  local row=${1:-} id="" nm="" ob=0 od lo="-" up="-" ttl="Add wallet" vob vod vlo="" vup=""
  local wid wn wob wod wlo wup wso
  dmy "$(date +%F)"; vod=$DMY
  if [[ -n $row ]]; then
    id=${row%%$'\t'*}; ttl="Edit wallet"
    # The list row has no opening data, so the full record is read from the file.
    IFS=$'\t' read -r wid wn wob wod wlo wup wso <<<"$(awk -F'\t' -v i="$id" '$1==i' "$WALS")"
    nm=$wn; ob=$wob; dmy "$wod"; vod=$DMY; lo=$wlo; up=$wup
  fi
  WF_ID=$id
  plain "$ob"; vob=${PL/./$DEC}
  if [[ $lo != - ]]; then plain "$lo"; vlo=${PL/./$DEC}; fi
  if [[ $up != - ]]; then plain "$up"; vup=${PL/./$DEC}; fi
  form_begin "$ttl" "" vd_wallet ""
  form_field Name text "$nm" "Unique name"
  form_field "Opening bal." smoney "$vob" "Balance on the opening date, may be negative"
  form_field "Opening date" date "$vod" "Entries before this date are ignored for this wallet"
  form_field "Lower bound" somoney "$vlo" "Optional. Warning when the balance falls to this or below"
  form_field "Upper bound" somoney "$vup" "Optional. Celebration when the balance reaches this"
  if run_form; then
    nm=${FV[0]}
    scents "${FV[1]}"; ob=$PM
    parse_date "${FV[2]}"; od=$PD
    lo=-; if [[ -n ${FV[3]} ]]; then scents "${FV[3]}"; lo=$PM; fi
    up=-; if [[ -n ${FV[4]} ]]; then scents "${FV[4]}"; up=$PM; fi
    if [[ -z $id ]]; then
      next_id; id=$NID; max_sort "$WALS" 7
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$nm" "$ob" "$od" "$lo" "$up" $((MS + 1)) >>"$WALS"
    else
      awk -F'\t' -v OFS='\t' -v i="$id" -v n="$nm" -v o="$ob" -v d="$od" -v lo="$lo" -v up="$up" \
        '$1==i{$2=n; $3=o; $4=d; $5=lo; $6=up} 1' "$WALS" | atomic "$WALS"
    fi
    flash "$C_OK" "Saved."; refresh
  else draw; fi
}
