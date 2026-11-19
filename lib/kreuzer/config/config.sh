# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# config/config.sh - settings file: defaults, load, write, derived values
#
# Depends on : text_trim, log_die, ACTIONS and KEYDEF (config/keys.sh, used at call time)
# Provides   : config_load config_write config_apply
# Globals    : CONF_DIR CONF_FILE CFG CFG_ORDER TH DEC ASP100 CSEP

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$APP"
CONF_FILE="$CONF_DIR/$APP.conf"

declare -gA CFG=([data_dir]="$HOME/Documents/$APP" [currency]="" [currency_pos]="prefix"
  [thousands]="," [decimal]="." [pie_aspect]="2.0" [auto_purge_days]="0")
# Associative arrays are unordered; this list keeps the written file stable.
CFG_ORDER=(data_dir currency currency_pos thousands decimal pie_aspect auto_purge_days)

# Unknown keys are fatal instead of ignored, so a typo in the file is reported
# at startup and not silently dropped.
config_load() {
  [[ -f $CONF_FILE ]] || return 0
  local viz_section="" line k v
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}; text_trim "$line"; line=$TRIM
    [[ -z $line ]] && continue
    if [[ $line =~ ^\[(.*)\]$ ]]; then viz_section=${BASH_REMATCH[1]}; continue; fi
    k=${line%%=*}; v=${line#*=}; text_trim "$k"; k=$TRIM; text_trim "$v"; v=$TRIM
    case $section in
      general) [[ -n ${CFG[$k]+x} ]] || log_die "unknown setting '$k' in $CONF_FILE"; CFG[$k]=$v ;;
      keys) [[ -n ${KEYDEF[$k]+x} ]] || log_die "unknown action '$k' in $CONF_FILE"; KEYDEF[$k]=${v// /} ;;
    esac
  done <"$CONF_FILE"
}

config_write() {
  local k a
  mkdir -p "$CONF_DIR"
  {
    echo "# $APP configuration"
    echo "[general]"
    for k in "${CFG_ORDER[@]}"; do echo "$k=${CFG[$k]}"; done
    echo
    echo "# Comma separated keys per action. Names: ENTER ESC TAB UP DOWN LEFT RIGHT SPACE COMMA BACKSPACE"
    echo "[keys]"
    for a in "${ACTIONS[@]}"; do echo "$a=${KEYDEF[$a]}"; done
  } >"$CONF_FILE"
}

# Turns raw settings into the values the rest of the code reads. Run again after
# any settings change.
config_apply() {
  CFG[data_dir]=${CFG[data_dir]/#\~/$HOME}
  case ${CFG[thousands]} in space) TH=" " ;; none) TH="" ;; *) TH=${CFG[thousands]} ;; esac
  DEC=${CFG[decimal]}
  # Identical separators would make "1.234.56" unreadable; drop grouping instead.
  [[ $TH == "$DEC" ]] && TH=""
  # Integer percent: bash arithmetic has no floats, awk does the conversion once.
  ASP100=$(awk -v a="${CFG[pie_aspect]}" 'BEGIN{printf "%d", a*100}')
  ((ASP100 >= 100 && ASP100 <= 400)) || ASP100=200
  CSEP=""; [[ ${CFG[currency]} =~ [[:alpha:]]$ ]] && CSEP=" "
}
