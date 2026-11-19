# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# forms/wallet.sh - add or edit a wallet with opening balance and bounds
#
# Depends on : ui/form.sh, data/store.sh
# Provides   : wallet_form wallet_validate
# Globals    : WF_ID
#
# meta/wallets.tsv columns: id, name, opening_cents, opening_date, lower, upper, sort_order
# "-" stands for "no bound".

WF_ID=""

wallet_validate() {
  local lo up
  if awk -F'\t' -v n="${FV[0],,}" -v i="$WF_ID" 'tolower($2)==n && $1!=i{f=1} END{exit !f}' "$WALS"; then
    FERR="a wallet with that name already exists"; return 1
  fi
  if [[ -n ${FV[3]} && -n ${FV[4]} ]]; then
    money_parse_signed "${FV[3]}"; lo=$PM; money_parse_signed "${FV[4]}"; up=$PM
    ((up > lo)) || { FERR="the upper bound must be above the lower bound"; return 1; }
  fi
}

wallet_form() { # [row]
  local row=${1:-} id="" nm="" ob=0 od lo="-" up="-" ttl="Add wallet" vob vod vlo="" vup=""
  local wid wn wob wod wlo wup wso
  date_display "$(date +%F)"; vod=$DMY
  if [[ -n $row ]]; then
    id=${row%%$'\t'*}; ttl="Edit wallet"
    # The list row has no opening data, so the full record is read from the file.
    IFS=$'\t' read -r wid wn wob wod wlo wup wso <<<"$(awk -F'\t' -v i="$id" '$1==i' "$WALS")"
    nm=$wn; ob=$wob; date_display "$wod"; vod=$DMY; lo=$wlo; up=$wup
  fi
  WF_ID=$id
  money_plain "$ob"; vob=${PL/./$DEC}
  if [[ $lo != - ]]; then money_plain "$lo"; vlo=${PL/./$DEC}; fi
  if [[ $up != - ]]; then money_plain "$up"; vup=${PL/./$DEC}; fi
  form_begin "$ttl" "" wallet_validate ""
  form_field Name text "$nm" "Unique name"
  form_field "Opening bal." smoney "$vob" "Balance on the opening date, may be negative"
  form_field "Opening date" date "$vod" "Entries before this date are ignored for this wallet"
  form_field "Lower bound" somoney "$vlo" "Optional. Warning when the balance falls to this or below"
  form_field "Upper bound" somoney "$vup" "Optional. Celebration when the balance reaches this"
  if form_run; then
    nm=${FV[0]}
    money_parse_signed "${FV[1]}"; ob=$PM
    date_parse "${FV[2]}"; od=$PD
    lo=-; if [[ -n ${FV[3]} ]]; then money_parse_signed "${FV[3]}"; lo=$PM; fi
    up=-; if [[ -n ${FV[4]} ]]; then money_parse_signed "${FV[4]}"; up=$PM; fi
    if [[ -z $id ]]; then
      store_next_id; id=$NID; store_max_sort "$WALS" 7
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$nm" "$ob" "$od" "$lo" "$up" $((MS + 1)) >>"$WALS"
    else
      awk -F'\t' -v OFS='\t' -v i="$id" -v n="$nm" -v o="$ob" -v d="$od" -v lo="$lo" -v up="$up" \
        '$1==i{$2=n; $3=o; $4=d; $5=lo; $6=up} 1' "$WALS" | store_atomic "$WALS"
    fi
    canvas_flash "$C_OK" "Saved."; refresh
  else draw; fi
}
