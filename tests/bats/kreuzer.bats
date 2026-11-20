#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Test suite: the smoke scripts (library level) plus command-line behaviour of
# the real launcher against a throwaway config and data directory.

setup() {
  ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)
  KZ=$ROOT/bin/kreuzer
  export NO_COLOR=1
  export XDG_CONFIG_HOME=$BATS_TEST_TMPDIR/conf
  mkdir -p "$XDG_CONFIG_HOME/kreuzer"
  CONF=$XDG_CONFIG_HOME/kreuzer/kreuzer.conf
  # An existing config file keeps the launcher from asking first-run questions.
  printf '[general]\ndata_dir=%s\ncurrency=$\n' "$BATS_TEST_TMPDIR/data" >"$CONF"
}

smoke() { run bash "$ROOT/tests/smoke_$1.sh"; [ "$status" -eq 0 ]; [[ $output == *"all passed"* ]]; }

@test "smoke: viz" { smoke viz; }
@test "smoke: screens" { smoke screens; }
@test "smoke: app and cli" { smoke app; }
@test "smoke: data layer" { smoke data; }
@test "smoke: writers" { smoke writers; }

@test "--version prints name and version" {
  run "$KZ" --version
  [ "$status" -eq 0 ]
  [[ $output == "kreuzer "* ]]
}

@test "--help shows usage and creates no files" {
  rm -f "$CONF"
  run "$KZ" --help
  [ "$status" -eq 0 ]
  [[ $output == *"Usage:"* ]]
  [ ! -e "$CONF" ]
}

@test "--dump-keys lists the bindings" {
  run "$KZ" --dump-keys
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "[keys]" ]
  [[ $output == *"quit=q"* ]]
}

@test "conflicting key bindings are rejected at startup" {
  printf '[keys]\nup=q\n' >>"$CONF"
  run "$KZ" export 2026-11
  [ "$status" -eq 1 ]
  [[ $output == *"is bound to both"* ]]
}

@test "unknown setting is reported" {
  printf 'bogus=1\n' >>"$CONF"
  run "$KZ" --dump-keys
  [ "$status" -eq 1 ]
  [[ $output == *"unknown setting 'bogus'"* ]]
}

@test "export rejects a malformed month" {
  run "$KZ" export bad
  [ "$status" -eq 1 ]
  [[ $output == *"month must look like"* ]]
}

@test "export reports a missing month" {
  run "$KZ" export 2026-11
  [ "$status" -eq 1 ]
  [[ $output == *"no data file"* ]]
}

@test "export prints CSV and marks unknown ids as DELETED" {
  mkdir -p "$BATS_TEST_TMPDIR/data"
  printf '1\t2026-11-03\t-\tE\t1250\t2\t1\t-\tlunch\n' >"$BATS_TEST_TMPDIR/data/2026-11.tsv"
  run "$KZ" export 2026-11
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "date,time,type,amount,category,wallet,note" ]
  [ "${lines[1]}" = '03/11/2026,,expense,-12.50,"DELETED","DELETED","lunch"' ]
}

@test "single-file build runs and matches the tree" {
  run bash "$ROOT/tools/dist.sh" "$BATS_TEST_TMPDIR/kreuzer-bundle"
  [ "$status" -eq 0 ]
  run "$BATS_TEST_TMPDIR/kreuzer-bundle" --version
  [ "$status" -eq 0 ]
  [[ $output == "kreuzer "* ]]
  diff <("$BATS_TEST_TMPDIR/kreuzer-bundle" --dump-keys) <("$KZ" --dump-keys)
}
