# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# data/store.sh - data directory, locking, atomic file helpers, id counter
#
# Depends on : CFG, die, trim
# Provides   : set_paths init_data auto_purge atomic row_remove next_id max_sort
#              all_months swap_sort
# Globals    : DATA CATS WALS QUOTAS BUDG TRASH SEQ NID MS
#
# Storage format: tab-separated files, one row per record. Empty fields are never
# written (a "-" is used instead) because `read` with a tab separator collapses
# empty fields and shifts every column after them.

set_paths() {
  DATA=${CFG[data_dir]}
  CATS="$DATA/meta/categories.tsv"; WALS="$DATA/meta/wallets.tsv"; QUOTAS="$DATA/meta/quotas.tsv"
  BUDG="$DATA/meta/budget.tsv"; TRASH="$DATA/meta/trash.tsv"; SEQ="$DATA/meta/seq"
}

init_data() {
  set_paths
  mkdir -p "$DATA/meta" || die "cannot create $DATA"
  touch "$CATS" "$WALS" "$QUOTAS" "$BUDG" "$TRASH"
  # fd 9 stays open for the life of the process, which holds the lock. The lock
  # is advisory and protects against two instances rewriting the same file.
  exec 9>"$DATA/.lock"
  flock -n 9 || die "another $APP instance is using $DATA"
}

auto_purge() {
  local d=${CFG[auto_purge_days]}
  [[ $d =~ ^[0-9]+$ ]] && ((d > 0)) || return 0
  awk -F'\t' -v c=$(($(date +%s) - d * 86400)) '$2>=c' "$TRASH" | atomic "$TRASH"
}

# Reads stdin into FILE via a temp file in the same directory, so the final mv is
# an atomic rename on one filesystem. A crash leaves either the old or the new
# file, never a half-written one.
atomic() { local f=$1 t; t=$(mktemp "$f.XXXXXX") || return 1; cat >"$t" && mv -f "$t" "$f"; }

row_remove() { [[ -f $1 ]] || return 0; awk -F'\t' -v id="$2" '$1!=id' "$1" | atomic "$1"; }

# Ids come from one counter shared by all record types, so an id is never reused
# and a restored item always finds its old references.
next_id() { local n=0; [[ -s $SEQ ]] && n=$(<"$SEQ"); n=$((n + 1)); echo "$n" >"$SEQ"; NID=$n; }

# max_sort FILE COLUMN -> MS (highest sort_order, 0 for an empty file)
max_sort() { MS=$(awk -F'\t' -v c="$2" '$c+0>m{m=$c+0} END{print m+0}' "$1"); }

all_months() { find "$DATA" -maxdepth 1 -name '[0-9][0-9][0-9][0-9]-[0-9][0-9].tsv' 2>/dev/null | sort; }

# Exchanges the sort_order values of two records (manual reordering).
swap_sort() { # file sortcol idA idB
  awk -F'\t' -v OFS='\t' -v c="$2" -v a="$3" -v b="$4" '
    { l[NR]=$0; id[NR]=$1; if ($1==a) sa=$c; if ($1==b) sb=$c }
    END { for (i=1;i<=NR;i++) { $0=l[i]; if (id[i]==a) $c=sb; else if (id[i]==b) $c=sa; print } }' "$1" | atomic "$1"
}
