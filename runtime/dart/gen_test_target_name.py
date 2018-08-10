#!/usr/bin/env python
# Copyright 2018 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import argparse
import sys


def main():
  """Generates a test target name given a file name.

  If the file name doesn't represent a test, this produces the empty string.

  Arguments:
    --file: The path to the test file.
  """
  parser = argparse.ArgumentParser(
      description='Replaces dots and slashes with underscores')
  parser.add_argument('--file',
                      help='File path to convert',
                      required=True)
  args = parser.parse_args()
  value = args.file
  if value.endswith('_test.dart'):
    for ch in ['.', '/']:
      if ch in value:
        value = value.replace(ch, '_')
    print(value)


if __name__ == '__main__':
  sys.exit(main())
