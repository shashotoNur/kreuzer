# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# forms/wallet.sh - add or edit a wallet with opening balance and bounds
#
# Depends on : ui/form.sh, data/wallets.sh
# Provides   : wallet_form wallet_validate
# Globals    : WF_ID

WF_ID=""

wallet_validate() {
  local lo up
  if wallet_name_exists "${FV[0]}" "$WF_ID"; then
    FERR="a wallet with that name already exists"; return 1
  fi
  if [[ -n ${FV[3]} && -n ${FV[4]} ]]; then
    money_parse_signed "${FV[3]}"; lo=$PM; money_parse_signed "${FV[4]}"; up=$PM
    ((up > lo)) || { FERR="the upper bound must be above the lower bound"; return 1; }
  fi
}

wallet_form() { # [row]
  local row=${1:-} id="" nm="" ob=0 od lo="-" up="-" ttl="Add wallet" vob vod vlo="" vup=""
  date_display "$(date +%F)"; vod=$DMY
  if [[ -n $row ]]; then
    id=${row%%$'\t'*}; ttl="Edit wallet"
    wallet_get "$id" || { canvas_flash "$C_BAD" "Wallet not found"; draw; return 0; }
    nm=$WG_NAME; ob=$WG_OPEN; date_display "$WG_DATE"; vod=$DMY; lo=$WG_LO; up=$WG_UP
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
    if [[ -z $id ]]; then wallet_create "$nm" "$ob" "$od" "$lo" "$up"
    else wallet_update "$id" "$nm" "$ob" "$od" "$lo" "$up"; fi
    canvas_flash "$C_OK" "Saved."; refresh
  else draw; fi
}
