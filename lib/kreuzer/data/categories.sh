# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# data/categories.sh - category lookups
#
# Depends on : data/store.sh
# Provides   : category_has_kind category_ensure_fee
# Globals    : FEEC
#
# meta/categories.tsv columns: id, kind (I or E), name, sort_order

category_has_kind() { awk -F'\t' -v k="$1" '$2==k{f=1} END{exit !f}' "$CATS"; }

# Returns the id of the "Transfer fees" expense category in FEEC, creating it on
# first use so transfer fees show up in expense totals like any other cost.
category_ensure_fee() {
  FEEC=$(awk -F'\t' '$2=="E" && $3=="Transfer fees"{print $1; exit}' "$CATS")
  if [[ -z $FEEC ]]; then
    store_next_id; FEEC=$NID; store_max_sort "$CATS" 4
    printf '%s\tE\tTransfer fees\t%s\n' "$FEEC" $((MS + 1)) >>"$CATS"
  fi
}
