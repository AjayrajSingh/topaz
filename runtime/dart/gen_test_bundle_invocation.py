#!/usr/bin/env python
# Copyright 2018 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import argparse
import os
import stat
import string
import sys


def main():
  parser = argparse.ArgumentParser(
      description='Generate a script that invokes multiple dart_test targets')
  parser.add_argument('--out',
                      help='Path to the invocation file to generate',
                      required=True)
  parser.add_argument('--test',
                      action='append',
                      help='Adds a target to the list of test executables',
                      required=True)
  parser.add_argument('--test-name',
                      action='append',
                      help='Adds a readable test name to the list of tests')
  args = parser.parse_args()

  test_file = args.out
  test_dir = os.path.dirname(test_file)
  if not os.path.exists(test_dir):
    os.makedirs(test_dir)

  test_failed_definition_block = '''
FAILED_TESTS=()
PIDS_NAMES=()

function run_test () {
  local test_exe="$1"
  local test_name="$2"
  echo "Running $test_name"
  env $test_exe & PIDS_NAMES+=($!:$test_name)
}

function test_failed () {
  FAILED_TESTS+=("$1")
}

'''

  test_wait_to_complete_block = '''
for pid_name in ${PIDS_NAMES[*]}; do
  pid="${pid_name%%:*}"
  name="${pid_name#*:}"
  wait $pid || test_failed $name
done
'''

  test_failed_check_block = '''
if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
  >&2 echo -e "\\e[91mThe following tests failed:\\e[0m"
  for test_name in "${FAILED_TESTS[@]}"; do
    >&2 echo -e "\\n  - \\e[91m$test_name\\e[0m"
  done
  exit 1
fi
'''

  script = '#!/bin/bash\n\n'
  if args.test_name:
    script += test_failed_definition_block
    # TODO(FL-104): Limit concurrency to number of cores
    for test_executable, test_name in zip(args.test, args.test_name):
      script += "run_test %s '%s'\n" % (test_executable, test_name)
    script += test_wait_to_complete_block
    script += test_failed_check_block
  else:
    for test_executable in args.test:
      script += '%s "$@"\n' % test_executable

  with open(test_file, 'w') as file:
      file.write(script)
  permissions = (stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR |
                 stat.S_IRGRP | stat.S_IWGRP | stat.S_IXGRP |
                 stat.S_IROTH)
  os.chmod(test_file, permissions)


if __name__ == '__main__':
  sys.exit(main())
