# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# data/categories.sh - category records
#
# Depends on : data/store.sh
# Provides   : category_has_kind category_ensure_fee category_name_exists
#              category_list category_create category_rename
# Globals    : FEEC CATL
# Out-vars   : NID
#
# meta/categories.tsv columns: id, kind (I or E), name, sort_order

FEEC=""; CATL=()

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

# category_name_exists KIND NAME [EXCLUDE_ID] : names are unique per kind,
# compared case-insensitively.
category_name_exists() {
  awk -F'\t' -v k="$1" -v n="${2,,}" -v i="${3:-}" 'tolower($3)==n && $2==k && $1!=i{f=1} END{exit !f}' "$CATS"
}

# category_list KIND -> CATL ("id<TAB>name" in manual sort order)
category_list() {
  mapfile -t CATL < <(awk -F'\t' -v OFS='\t' -v k="$1" '$2==k{print $4, $1, $3}' "$CATS" |
    sort -t$'\t' -k1,1n | cut -f2-)
}

category_create() { # kind name -> NID
  local so
  store_next_id; store_max_sort "$CATS" 4; so=$((MS + 1))
  printf '%s\t%s\t%s\t%s\n' "$NID" "$1" "$2" "$so" >>"$CATS"
}

# The kind is never changed after creation: it would silently reclassify old
# transactions.
category_rename() { # id name
  awk -F'\t' -v OFS='\t' -v i="$1" -v n="$2" '$1==i{$3=n} 1' "$CATS" | store_atomic "$CATS"
}
