#!/bin/bash
# Copyright 2017 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Exit this script if one command fails.
set -e

# TODO(jasoncampbell): Do something a little better than requiring an env var
# to be set.
source "${FUCHSIA_DIR}/scripts/env.sh"

function main() {
  echo "=== buidling Fuchsia"

  local gen_args=""

  while [[ $# -ne 0 ]]; do
    case $1 in
      --gen-arg)
        gen_args="${gen_args} $2"
        shift
        ;;
    esac
    shift
  done

  fset x86-64 "$@"
  if [[ -z "${gen_args}" ]]; then
    fgen
  else
    fgen "${gen_args}"
  fi

  fbuild
}

main "$@"
