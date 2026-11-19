# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# data/budget.sh - monthly budget and category quotas
#
# Depends on : data/store.sh
# Provides   : budget_for set_quota prune_quotas
# Out-vars   : BUD
#
# meta/budget.tsv columns: effective_month, cents
# meta/quotas.tsv columns: effective_month, category_id, cents
#
# Both are "effective from" records: the value for a month is the latest record
# at or before it. Changing a value therefore never rewrites history, and past
# months keep reporting the budget they were actually lived under.

# budget_for MONTH -> BUD (0 when none is set)
budget_for() {
  BUD=$(awk -F'\t' -v m="$1" '$1<=m && (!s || $1>=em){em=$1; b=$2; s=1} END{print b+0}' "$BUDG")
}

# Applies from the current calendar month, not the month being viewed, so
# browsing an old month and editing cannot rewrite the past.
set_quota() { # category_id cents
  local m; printf -v m '%(%Y-%m)T' -1
  awk -F'\t' -v m="$m" -v c="$1" '!($1==m && $2==c)' "$QUOTAS" | atomic "$QUOTAS"
  printf '%s\t%s\t%s\n' "$m" "$1" "$2" >>"$QUOTAS"
}

# Drops quotas of categories that no longer exist anywhere (after emptying trash).
prune_quotas() {
  awk -F'\t' 'FILENAME==ARGV[1]{k[$1]=1; next} ($2 in k)' "$CATS" "$QUOTAS" | atomic "$QUOTAS"
}
