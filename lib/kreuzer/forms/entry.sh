# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# forms/entry.sh - income and expense form, plus helpers shared by all forms
#
# Depends on : ui/form.sh, domain/alerts.sh, data/*, viz/entry.sh
# Provides   : entry_form pv_entry pk_wallet pk_cats pk_cat_I pk_cat_E def_date save_done
# Globals    : FKIND OLD_M OLD_AMT OLD_WAL LASTW
#
# Forms never reload data themselves: after a write they call save_done, which
# goes through refresh so charts and caches stay consistent.

FKIND=""; OLD_M=""; OLD_AMT=0; OLD_WAL=""; LASTW=""

# Pickers fill PICK with "id<TAB>label". Passed to form_field as pick:FN.
pk_wallet() {
  local l id nm x; PICK=()
  for l in "${WB[@]}"; do IFS=$'\t' read -r id nm x <<<"$l"; PICK+=("$id"$'\t'"$nm"); done
}
pk_cats() { # kind
  mapfile -t PICK < <(awk -F'\t' -v OFS='\t' -v k="$1" '$2==k{print $4, $1, $3}' "$CATS" |
    sort -t$'\t' -k1,1n | cut -f2-)
}
pk_cat_I() { pk_cats I; }
pk_cat_E() { pk_cats E; }

# Default date of a new entry: the viewed day, today if the viewed month is the
# current one, otherwise the first of the viewed month. Always shown for
# confirmation, never silently applied.
def_date() { # -> DMY
  local t; printf -v t '%(%F)T' -1
  if [[ $SCREEN == daily ]]; then dmy "$DAY"
  elif [[ ${t:0:7} == "$MONTH" ]]; then dmy "$t"
  else dmy "$MONTH-01"; fi
}

# A save may land in a month other than the one on screen (the date field is
# free), so say where it went; otherwise the entry would seem to vanish.
save_done() { # iso_date
  local m=${1:0:7} msg="Saved."
  [[ $m == "$MONTH" || $SCREEN == search || $SCREEN == daily ]] || msg="Saved in $m (not the month shown)."
  flash "$C_OK" "$msg"; refresh; show_alerts
}

# Live preview under the form: projected wallet balance, quota and budget
# effects. It also feeds ENT_* so the charts show the state after saving. When
# editing, only the change against the old values counts (OLD_*), otherwise the
# entry would be counted twice.
pv_entry() {
  local na=0 d l id kd nm sp q nb a b col msg=""
  ENT_MONTH=$MONTH; ENT_CAT=${FID[1]}; ENT_WAL=${FID[2]}; ENT_WAL2=""
  parse_money "${FV[0]}" && na=$PM
  parse_date "${FV[3]}" && ENT_MONTH=${PD:0:7}
  ENT_AMT=$na; [[ $ENT_MONTH == "$OLD_M" ]] && ENT_AMT=$((na - OLD_AMT))
  ent_load
  PVL=()
  if wb_get "$ENT_WAL"; then
    d=$na; [[ $ENT_WAL == "$OLD_WAL" ]] && d=$((na - OLD_AMT))
    [[ $FKIND == E ]] && d=$((-d))
    nb=$((WBB + d)); fm "$WBB"; a=$M; fm "$nb"; b=$M; col=$C_TXT
    if [[ $WBL != - ]] && ((nb <= WBL)); then col=$C_WARN; msg="  below lower bound"; fi
    if [[ $WBU != - ]] && ((nb >= WBU)); then col=$C_OK; msg="  upper bound reached"; fi
    PVL+=("${C_DIM}$WBN${RST}  $a → ${col}$b${RST}${C_DIM}$msg${RST}")
  fi
  if [[ $FKIND == E ]]; then
    for l in "${ENT_CS[@]}"; do
      IFS=$'\t' read -r id kd nm sp q <<<"$l"
      [[ $id == "$ENT_CAT" ]] || continue
      if ((q > 0 && sp + ENT_AMT > q)); then fm $((sp + ENT_AMT - q)); PVL+=("${C_WARN}$nm would be over its quota by $M${RST}"); fi
    done
    if ((ENT_BUD > 0 && ENT_EXP + ENT_AMT > ENT_BUD)); then
      fm $((ENT_EXP + ENT_AMT - ENT_BUD)); PVL+=("${C_WARN}The monthly budget would be exceeded by $M${RST}")
    fi
  fi
}

# entry_form KIND [ROW] : add (no row) or edit (a load_tx row) an income or expense.
# Editing removes the old row and appends the new one, so a changed date moves
# the entry to the right month file without special handling.
entry_form() {
  local kind=$1 row=${2:-} id="" dt k cents cat wal note tr cid wid d t nt ttl pk vz od="" tm
  local va="" vc="" vcid="" vw="" vwid="" vnt="" vtm="" vd
  ((${#WB[@]})) || { flash "$C_WARN" "Create a wallet first (screen 5)"; draw; return 0; }
  if [[ -n $row ]]; then IFS=$'\t' read -r id dt k cents cat wal note tr cid wid <<<"$row"; kind=$k; fi
  has_cat "$kind" || { flash "$C_WARN" "Create a category of this type first (screen 4)"; draw; return 0; }
  FKIND=$kind; OLD_M=""; OLD_AMT=0; OLD_WAL=""
  if [[ $kind == I ]]; then ttl="Add income"; pk=pk_cat_I; vz=viz_entry_income
  else ttl="Add expense"; pk=pk_cat_E; vz=viz_entry_expense; fi
  def_date; vd=$DMY
  IFS=$'\t' read -r vwid vw _ <<<"${WB[0]}"
  # The last used wallet is preselected: people tend to enter in runs.
  [[ -n $LASTW ]] && wname "$LASTW" && { vwid=$LASTW; vw=$WNM; }
  if [[ -n $id ]]; then
    ttl=${ttl/Add/Edit}; od=${dt%% *}; tm=${dt#* }
    [[ $tm == - ]] && tm=""; [[ $note == - ]] && note=""
    dmy "$od"; vd=$DMY; plain "$cents"; va=${PL/./$DEC}; vtm=$tm; vnt=$note
    # A DELETED category or wallet must be chosen again; there is nothing to keep.
    vc=$cat; vcid=$cid; [[ $cat == DELETED ]] && { vc=""; vcid=""; }
    vw=$wal; vwid=$wid; [[ $wal == DELETED ]] && { vw=""; vwid=""; }
    OLD_M=${od:0:7}; OLD_AMT=$cents; OLD_WAL=$wid
  fi
  form_begin "$ttl" pv_entry "" "$vz"
  form_field Amount money "$va" "Amount, for example 12.50"
  form_field Category "pick:$pk" "$vc" "Enter to choose, type a letter to jump" "$vcid"
  form_field Wallet "pick:pk_wallet" "$vw" "Enter to choose" "$vwid"
  form_field Date date "$vd" "DD/MM/YYYY, or DD/MM for this year"
  form_field Time time "$vtm" "HH:MM, optional"
  form_field Note otext "$vnt" "Optional"
  if run_form; then
    parse_money "${FV[0]}"; cents=$PM
    parse_date "${FV[3]}"; d=$PD
    t=${FV[4]}; [[ -n $t ]] || t=-
    nt=${FV[5]//$'\t'/ }; [[ -n $nt ]] || nt=-
    if [[ -n $id ]]; then row_remove "$DATA/${od:0:7}.tsv" "$id"; else next_id; id=$NID; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t-\t%s\n' "$id" "$d" "$t" "$kind" "$cents" "${FID[1]}" "${FID[2]}" "$nt" >>"$DATA/${d:0:7}.tsv"
    LASTW=${FID[2]}
    alert_state "${d:0:7}" "${FID[1]}" "${FID[2]}" "" "$kind"
    save_done "$d"
  else draw; fi
}
