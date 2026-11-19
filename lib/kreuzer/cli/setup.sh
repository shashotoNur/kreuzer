# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# cli/setup.sh - first-run questions on the plain terminal
#
# Depends on : config/config.sh, domain/balances.sh (parse_money), data/store.sh
# Provides   : first_run ensure_basics
#
# These run before the TUI starts, so they use read -p instead of the form
# engine: no alternate screen is needed to ask three questions.

first_run() {
  local c
  echo "Welcome to $APP $VERSION. Quick setup (change it later with 'C' inside the app)."
  read -r -p "Currency symbol or name (e.g. \$, EUR): " c; CFG[currency]=${c:-\$}
  read -r -p "Symbol position [prefix/suffix] (prefix): " c; [[ $c == suffix ]] && CFG[currency_pos]=suffix
  read -r -p "Thousands separator: , . space none (,): " c
  case $c in .|space|none) CFG[thousands]=$c ;; esac
  read -r -p "Decimal separator: . or , (.): " c; [[ $c == , ]] && CFG[decimal]=,
  write_config; apply_cfg
}

# Guarantees at least one wallet, so the first income or expense can be entered
# immediately. Starter categories are optional and skipped if any exist.
ensure_basics() {
  local n c a e
  if [[ ! -s $WALS ]]; then
    read -r -p "Name of your first wallet (Cash): " n; n=${n:-Cash}
    read -r -p "Opening balance (0): " a; a=${a:-0}; parse_money "$a" || PM=0
    next_id; printf '%s\t%s\t%s\t%s\t-\t-\t1\n' "$NID" "${n//$'\t'/ }" "$PM" "$(date +%F)" >>"$WALS"
  fi
  if [[ ! -s $CATS ]]; then
    read -r -p "Create starter categories (Salary, Food, Rent, ...)? [Y/n]: " c
    if [[ $c != [nN]* ]]; then
      local i=0
      for e in "I:Salary" "I:Other income" "E:Food" "E:Rent" "E:Transport" "E:Bills" "E:Leisure"; do
        i=$((i + 1)); next_id; printf '%s\t%s\t%s\t%s\n' "$NID" "${e%%:*}" "${e#*:}" "$i" >>"$CATS"
      done
    fi
  fi
}
