# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# core/money.sh - amounts as integer cents: parsing and display
#
# Depends on : CFG, TH, DEC, CSEP (set by config_apply; needed at call time only)
# Provides   : money_parse money_plain money_format money_parse_signed
# Out-vars   : PM PL M
#
# Money is stored and computed as integer cents. Floats would drift by a cent and
# make the unused-budget figures untrustworthy.

# Accepts "12", "12.5" and "12,50": users type what their keyboard layout gives
# them. Thousands separators are rejected because "1,234" would be ambiguous.
# 10# avoids "08" being read as invalid octal.
money_parse() {
  local s=${1//[[:space:]]/}; s=${s//,/.}
  [[ $s =~ ^([0-9]+)(\.([0-9]{1,2}))?$ ]] || return 1
  local f=${BASH_REMATCH[3]}00; f=${f:0:2}
  PM=$((10#${BASH_REMATCH[1]} * 100 + 10#$f))
}

# Plain "d.dd" for storage and form fields. The sign is split off first because
# bash division truncates toward zero and -5 would print as "0.-5".
money_plain() { local c=$1 n=""; ((c < 0)) && { n=-; c=$((-c)); }; printf -v PL '%s%d.%02d' "$n" $((c / 100)) $((c % 100)); }

# Display form with the user's separators and currency. Digits are grouped from
# the right. CSEP is a space only for alphabetic currencies ("EUR 5", "$5").
money_format() {
  local c=$1 neg="" w s out="" f
  ((c < 0)) && { neg="-"; c=$((-c)); }
  w=$((c / 100)); printf -v f '%02d' $((c % 100)); s=$w
  while ((${#s} > 3)); do out="$TH${s: -3}$out"; s=${s:0:${#s}-3}; done
  out="$s$out$DEC$f"
  if [[ ${CFG[currency_pos]} == suffix ]]; then M="$neg$out ${CFG[currency]}"
  else M="$neg${CFG[currency]}$CSEP$out"; fi
}

# Signed variant, for balances and bounds that may be negative.
money_parse_signed() {
  local s=$1 neg=0
  [[ $s == -* ]] && { neg=1; s=${s#-}; }
  money_parse "$s" || return 1
  ((neg)) && PM=$((-PM))
  return 0
}
