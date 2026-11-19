# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# ui/form.sh - generic form engine: field validation, editing, navigation
#
# Depends on : ui/widgets.sh, ui/draw.sh (draw_form), core/money, core/dates
# Provides   : form_begin form_field field_check run_form
# Globals    : FTITLE FVIZ FERR FDIRTY CHK FH FID  (FL FV FA FCUR FPREVFN FVALID in state)
# Out-vars   : after run_form returns 0, FV[i] holds the normalised display value
#              and FID[i] the id of a picked item
#
# A form is declared with form_begin plus one form_field per row, then run.
# Field types:
#   text otext         required / optional text
#   money omoney       amount above zero / optional amount
#   smoney somoney     signed amount, required / optional
#   date time          DD/MM/YYYY (DD/MM allowed) and HH:MM
#   pick:FN opick:FN   choose from the PICK list filled by function FN
#   choice:A|B|C       cycle through fixed options with Enter

FTITLE=""; FVIZ=""; FERR=""; FDIRTY=1; CHK=""
FH=(); FID=()

form_begin() { # title [previewfn] [validfn] [vizfn]
  FTITLE=$1; FPREVFN=${2:-}; FVALID=${3:-}; FVIZ=${4:-}
  FL=(); FV=(); FA=(); FH=(); FID=(); PVL=(); FERR=""
}

form_field() { # label type value [hint] [id]
  FL+=("$1"); FA+=("$2"); FV+=("$3"); FH+=("${4:-}"); FID+=("${5:-}")
}

# field_check INDEX VALUE -> CHK (normalised value). On failure sets FERR and
# returns 1. Normalising here (not only validating) keeps what is shown, what is
# previewed and what is stored identical: "12,5" becomes "12.50".
field_check() {
  local t=${FA[$1]} v=$2 sg=""
  v=${v//$'\t'/ }; trim "$v"; v=$TRIM; FERR=""
  case ${t%%:*} in
    text) [[ -n $v ]] || { FERR="required"; return 1; } ;;
    money | omoney)
      if [[ -n $v || ${t%%:*} == money ]]; then
        parse_money "$v" || { FERR="enter an amount like 12.50"; return 1; }
        if [[ ${t%%:*} == money ]] && ((PM == 0)); then FERR="amount must be above zero"; return 1; fi
        plain "$PM"; v=${PL/./$DEC}
      fi ;;
    smoney | somoney)
      if [[ -z $v ]]; then
        [[ ${t%%:*} == somoney ]] || { FERR="required"; return 1; }
      else
        [[ $v == -* ]] && { sg=-; v=${v#-}; }
        parse_money "$v" || { FERR="enter an amount like 12.50 or -5"; return 1; }
        plain "$PM"; v=$sg${PL/./$DEC}
      fi ;;
    date)
      parse_date "$v" || { FERR="date must be DD/MM/YYYY (or DD/MM)"; return 1; }
      dmy "$PD"; v=$DMY ;;
    time)
      if [[ -n $v ]]; then
        [[ $v =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]] || { FERR="time must be HH:MM"; return 1; }
        printf -v v '%02d:%s' "$((10#${v%%:*}))" "${v#*:}"
      fi ;;
    pick) [[ -n ${FID[$1]} ]] || { FERR="choose a value"; return 1; } ;;
  esac
  CHK=$v
}

# Used as EDIT_CHECK by the line editor so Enter is refused until the field is valid.
chk_field() { field_check "$EDIT" "$EBUF" && return 0; flash "$C_BAD" "$FERR"; return 1; }

# edit_field INDEX : status 0 if a value was accepted.
edit_field() {
  local i=$1 rc=1
  EDIT=$i; EBUF=${FV[i]}; EPOS=${#EBUF}; EDIT_CHECK=chk_field
  if edit_loop; then field_check "$i" "$EBUF"; FV[i]=$CHK; FDIRTY=1; rc=0; fi
  EDIT=-1; EDIT_CHECK=""; return $rc
}

# Re-validates every field on save, then runs the form-level validator, because a
# value can be fine on its own and wrong in combination (for example two equal wallets).
form_submit() {
  local i
  for ((i = 0; i < ${#FL[@]}; i++)); do
    if ! field_check "$i" "${FV[i]}"; then FCUR=$i; flash "$C_BAD" "${FL[i]}: $FERR"; return 1; fi
    FV[i]=$CHK
  done
  if [[ -n $FVALID ]]; then
    FERR=""
    "$FVALID" || { flash "$C_BAD" "${FERR:-invalid input}"; return 1; }
  fi
  return 0
}

# Status 0 when saved, 1 when cancelled. FDIRTY makes draw_form recompute the
# preview only after a value changed, not on every cursor move.
run_form() {
  local n=${#FL[@]} act t v i idx
  local -a opts
  MODE=form; FCUR=0; FDIRTY=1; EDIT=-1; OVERLAY=""
  while :; do
    draw; read_key; MSG=""
    case $KEY in RESIZE) continue ;; EOF) MODE=list; return 1 ;; esac
    act=${KEYMAP[$KEY]:-}
    case $KEY in TAB) act=down ;; SHIFT_TAB) act=up ;; esac
    case $act in
      up) ((FCUR > 0)) && FCUR=$((FCUR - 1)) ;;
      down) ((FCUR < n)) && FCUR=$((FCUR + 1)) ;;
      top) FCUR=0 ;;
      bottom) FCUR=$n ;;
      back) MODE=list; return 1 ;;
      select)
        if ((FCUR == n)); then
          if form_submit; then MODE=list; return 0; fi
        else
          t=${FA[FCUR]}
          case ${t%%:*} in
            choice)
              IFS='|' read -ra opts <<<"${t#choice:}"
              v=${FV[FCUR]}; cycle v "${opts[@]}"; FV[FCUR]=$v; FDIRTY=1 ;;
            pick | opick)
              PICK=(); "${t#*:}"; idx=0
              for ((i = 0; i < ${#PICK[@]}; i++)); do
                if [[ ${PICK[i]%%$'\t'*} == "${FID[FCUR]}" ]]; then idx=$i; break; fi
              done
              if pick_list "${FL[FCUR]}" "$idx"; then
                FV[FCUR]=$PICK_LABEL; FID[FCUR]=$PICK_ID; FDIRTY=1; FCUR=$((FCUR + 1))
              fi ;;
            *) edit_field "$FCUR" && FCUR=$((FCUR + 1)) ;;
          esac
        fi ;;
    esac
  done
}
