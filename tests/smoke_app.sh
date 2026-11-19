#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Smoke test for lib/kreuzer/app and lib/kreuzer/cli: navigation, dispatch,
# export, backup and first-run setup against a throwaway directory.

set -f
export NO_COLOR=1

APP=kreuzer; VERSION=0.0.0-test
root=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)
lib=$root/lib/kreuzer

for m in core/log core/text core/list core/money core/dates core/deps config/config config/keys \
  ui/theme ui/state data/store data/categories data/transactions data/budget data/trash \
  domain/balances domain/totals domain/series domain/alerts ui/term ui/input ui/canvas \
  ui/widgets ui/draw viz/bars viz/pie viz/blocks screens/common screens/dashboard \
  screens/transactions screens/daily screens/categories screens/wallets screens/budget \
  screens/search screens/trash app/actions cli/help cli/setup cli/export cli/backup cli/check; do
  # shellcheck source=/dev/null
  source "$lib/$m.sh" || exit 1
done

# Nothing may reach a terminal: draw is replaced by a no-op.
draw() { :; }

tmp=$(mktemp -d); out=""
trap 'rm -rf "$tmp"; [[ -n $out ]] && rm -f "$out"' EXIT
CONF_DIR=$tmp/conf; CONF_FILE=$CONF_DIR/$APP.conf
CFG[data_dir]=$tmp/data; CFG[currency]='$'; config_apply; store_set_paths; keys_build
mkdir -p "$DATA/meta"; touch "$QUOTAS" "$BUDG" "$TRASH"
printf '1\tCash\t10000\t2026-01-01\t-\t-\t1\n' >"$WALS"
printf '2\tE\tFood\t1\n3\tI\tSalary\t2\n' >"$CATS"
printf '4\t2026-11-03\t-\tE\t1250\t2\t1\t-\tlunch\n5\t2026-11-01\t-\tI\t300000\t3\t1\t-\t-\n' >"$DATA/2026-11.tsv"
MONTH=2026-11

fail=0
check() { if [[ $2 == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: got [$2] want [$3]"; fail=1; fi; }

before=$DVER; refresh
check "refresh bumps DVER" $((DVER - before)) 1

nav_goto_screen transactions
check "nav_goto_screen" "$SCREEN" transactions
dispatch down;   check "dispatch down" "$SEL" 1
dispatch top;    check "dispatch top" "$SEL" 0
dispatch bottom; check "dispatch bottom" "$SEL" 1
dispatch next_screen; check "next_screen" "$SCREEN" daily
dispatch toggle_viz;  check "toggle_viz" "$SHOWVIZ" 1
dispatch quit;        check "quit" "$QUIT" 1

nav_shift_month -1; check "nav_shift_month back" "$MONTH" 2026-10
nav_shift_month +1; check "nav_shift_month forward" "$MONTH" 2026-11
nav_shift_day -1 >/dev/null; nav_shift_day +1

SCREEN=transactions; action_sort
check "action_sort cycles" "$TXSORT" amount

exp=$(cli_export 2026-11)
check "export header" "${exp%%$'\n'*}" "date,time,type,amount,category,wallet,note"
check "export expense row" "$(sed -n 2p <<<"$exp")" '03/11/2026,,expense,-12.50,"Food","Cash","lunch"'
check "export income row" "$(sed -n 3p <<<"$exp")" '01/11/2026,,income,3000.00,"Salary","Cash",""'
err=$( (cli_export bad) 2>&1 )
[[ $err == *"month must look like"* ]] && r=yes || r=no
check "export rejects bad month" "$r" yes

out=$(cli_backup)
tar -tzf "$out" | grep -q 'data/2026-11.tsv' && r=yes || r=no
check "backup contains month file" "$r" yes

check "cli_usage first line" "$(cli_usage | head -1)" "kreuzer 0.0.0-test - income, expense and budget tracker"

cli_first_run <<<$'EUR\nsuffix\n.\n,' >/dev/null
check "cli_first_run currency" "${CFG[currency]}|${CFG[currency_pos]}|${CFG[thousands]}|${CFG[decimal]}" "EUR|suffix|.|,"
grep -q '^currency=EUR$' "$CONF_FILE" && r=yes || r=no
check "cli_first_run wrote config" "$r" yes

mkdir -p "$tmp/fresh/meta"; CFG[data_dir]=$tmp/fresh; store_set_paths; touch "$QUOTAS" "$BUDG" "$TRASH" "$WALS" "$CATS"
cli_ensure_basics <<<$'Bank\n50' >/dev/null
check "cli_ensure_basics wallet" "$(cut -f2,3 "$WALS")" $'Bank\t5000'
check "cli_ensure_basics categories" "$(wc -l <"$CATS")" 7

cli_check 2>/dev/null | grep -q 'all required tools found' && r=yes || r=no
check "cli_check passes" "$r" yes

((fail)) && { echo "FAILED"; exit 1; }
echo "all passed"
