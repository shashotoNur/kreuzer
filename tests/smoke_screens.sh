#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Smoke test for lib/kreuzer/screens: loaders and row renderers against a
# throwaway data directory. Needs no terminal.

set -f
export NO_COLOR=1

APP=kreuzer
root=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)
lib=$root/lib/kreuzer

for m in core/log core/text core/list core/money core/dates config/config config/keys \
  ui/theme ui/state data/store data/categories data/transactions data/budget data/trash \
  domain/balances domain/totals domain/series domain/alerts ui/term ui/canvas \
  viz/bars viz/pie viz/blocks screens/common screens/dashboard screens/transactions \
  screens/daily screens/categories screens/wallets screens/budget screens/search screens/trash; do
  # shellcheck source=/dev/null
  source "$lib/$m.sh" || exit 1
done

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
CFG[data_dir]=$tmp; CFG[currency]='$'; apply_cfg; set_paths
mkdir -p "$DATA/meta"; touch "$QUOTAS" "$BUDG" "$TRASH"
printf '1\tCash\t10000\t2026-01-01\t-\t-\t1\n' >"$WALS"
printf '2\tE\tFood\t1\n3\tI\tSalary\t2\n' >"$CATS"
printf '4\t2026-11-03\t-\tE\t1250\t2\t1\t-\tlunch\n5\t2026-11-01\t-\tI\t300000\t3\t1\t-\t-\n' >"$DATA/2026-11.tsv"
MONTH=2026-11; MONTH_LABEL="November 2026"; LW=60; TXWAL=0

fail=0
check() { if [[ $2 == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: got [$2] want [$3]"; fail=1; fi; }

load_wb
check "net worth" "$NW_TXT" '$3,087.50'

load_transactions
check "transaction count" "${#ROWS_DATA[@]}" 2
row_transactions "${ROWS_DATA[0]}"
[[ $RR == *lunch* && $RR == *'-$12.50'* ]] && r=yes || r=no
check "row shows note and signed amount" "$r" yes

load_dashboard
check "dashboard not selectable" "$SELECTABLE" 0
check "dashboard totals" "$INC $EXP" "300000 1250"

load_categories
check "category count" "${#ROWS_DATA[@]}" 2

load_wallets
check "wallet count" "${#ROWS_DATA[@]}" 1

load_budget
check "budget has the viewed month" "${ROWS_DATA[0]%%$'\t'*}" 2026-11

QUERY="lunch"; load_search
check "search finds one match" "${#ROWS_DATA[@]}" 1

load_trash
check "trash starts empty" "${#ROWS_DATA[@]}" 0

SCREEN=daily; DAY_LABEL="x"; ROWS_DATA=(a b); title_daily
[[ $TL == "Day: x - 2 items - sort: date"* ]] && r=yes || r=no
check "list_title dispatch" "$r" yes

((fail)) && { echo "FAILED"; exit 1; }
echo "all passed"

