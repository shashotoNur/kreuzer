# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# ui/input.sh - keyboard input
#
# Depends on : nothing
# Provides   : input_read_key input_key_label
# Out-vars   : KEY KN
#
# KEY is a printable character or one of: ENTER ESC TAB SHIFT_TAB SPACE COMMA
# BACKSPACE UP DOWN LEFT RIGHT HOME END DELETE PGUP PGDN CTRL_A CTRL_E CTRL_K
# CTRL_U RESIZE EOF UNKNOWN. Space and comma get names because the config file
# separates keys with commas and trims spaces.

KEY=""; KN=""

input_read_key() {
  local k c seq rc
  KEY=""
  IFS= read -rsn1 k; rc=$?
  # A trapped signal (the WINCH from a resize) interrupts read with a status
  # above 128; reporting it as a key lets the caller redraw.
  if ((rc > 128)); then KEY=RESIZE; return 0; fi
  if ((rc != 0)); then KEY=EOF; return 0; fi
  case $k in
    "") KEY=ENTER ;;
    $'\t') KEY=TAB ;;
    " ") KEY=SPACE ;;
    ",") KEY=COMMA ;;
    $'\x7f' | $'\b') KEY=BACKSPACE ;;
    $'\x01') KEY=CTRL_A ;;
    $'\x05') KEY=CTRL_E ;;
    $'\x0b') KEY=CTRL_K ;;
    $'\x15') KEY=CTRL_U ;;
    $'\e')
      # A lone Esc and an escape sequence both start with the same byte. The
      # short timeout tells them apart: sequences arrive in one burst.
      if IFS= read -rsn1 -t 0.03 c; then
        if [[ $c == "[" || $c == "O" ]]; then
          seq=""
          while IFS= read -rsn1 -t 0.03 c; do
            seq+=$c
            [[ $c == [A-Za-z~] ]] && break
          done
          case $seq in
            A) KEY=UP ;; B) KEY=DOWN ;; C) KEY=RIGHT ;; D) KEY=LEFT ;;
            H | 1~ | 7~) KEY=HOME ;; F | 4~ | 8~) KEY=END ;;
            3~) KEY=DELETE ;; 5~) KEY=PGUP ;; 6~) KEY=PGDN ;; Z) KEY=SHIFT_TAB ;;
            *) KEY=UNKNOWN ;;
          esac
        else KEY=ESC; fi
      else KEY=ESC; fi ;;
    *) KEY=$k ;;
  esac
}

# input_key_label KEYNAME -> KN : label for footers and help ("ENTER" becomes "Enter").
input_key_label() {
  case $1 in
    ENTER) KN=Enter ;; ESC) KN=Esc ;; TAB) KN=Tab ;; SPACE) KN=Space ;; COMMA) KN="," ;;
    UP) KN="↑" ;; DOWN) KN="↓" ;; LEFT) KN="←" ;; RIGHT) KN="→" ;; BACKSPACE) KN=Bksp ;;
    *) KN=$1 ;;
  esac
}
