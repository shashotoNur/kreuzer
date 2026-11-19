# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# core/money.sh - amounts as integer cents: parsing and display
#
# Depends on : CFG[currency] CFG[currency_pos] TH DEC CSEP (set by config/config.sh
#              apply_cfg; only needed when fm is called, not when this file loads)
# Provides   : parse_money plain fm scents
# Out-vars   : PM PL M
#
# Money is stored and computed as integer cents everywhere. Floats would make
# totals drift by a cent and make the "unused budget" figures untrustworthy.

# Accepts "12", "12.5", "12,50". Both separators are accepted on input regardless
# of display settings because users type what their keyboard layout gives them.
# Thousands separators are rejected on purpose: "1,234" would be ambiguous.
# 10# forces base 10, otherwise "08" is read as invalid octal.
parse_money() {
  local s=${1//[[:space:]]/}; s=${s//,/.}
  [[ $s =~ ^([0-9]+)(\.([0-9]{1,2}))?$ ]] || return 1
  local f=${BASH_REMATCH[3]}00; f=${f:0:2}
  PM=$((10#${BASH_REMATCH[1]} * 100 + 10#$f))
}

# Cents to a plain "d.dd" string for storage and form fields. The sign is split
# off first: bash division truncates toward zero, so -5 would print as "0.-5".
plain() { local c=$1 n=""; ((c < 0)) && { n=-; c=$((-c)); }; printf -v PL '%s%d.%02d' "$n" $((c / 100)) $((c % 100)); }

# Cents to a display string using the user's separators and currency.
# Grouping is built from the right in chunks of three digits.
fm() {
  local c=$1 neg="" w s out="" f
  ((c < 0)) && { neg="-"; c=$((-c)); }
  w=$((c / 100)); printf -v f '%02d' $((c % 100)); s=$w
  while ((${#s} > 3)); do out="$TH${s: -3}$out"; s=${s:0:${#s}-3}; done
  out="$s$out$DEC$f"
  # CSEP is a space only for alphabetic currencies ("EUR 5" but "$5").
  if [[ ${CFG[currency_pos]} == suffix ]]; then M="$neg$out ${CFG[currency]}"
  else M="$neg${CFG[currency]}$CSEP$out"; fi
}

# Signed variant of parse_money (balances and bounds may be negative).
scents() {
  local s=$1 neg=0
  [[ $s == -* ]] && { neg=1; s=${s#-}; }
  parse_money "$s" || return 1
  ((neg)) && PM=$((-PM))
  return 0
}
