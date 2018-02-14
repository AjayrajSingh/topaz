#!/usr/bin/env python
# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import argparse
import subprocess
import os
import sys


def main():
  parser = argparse.ArgumentParser(description='Package a Flutter application')

  parser.add_argument('--flutter-root', type=str, required=True,
                      help='The root of the Flutter SDK')
  parser.add_argument('--flutter-tools', type=str, required=True,
                      help='The executable for the Flutter tool')
  parser.add_argument('--working-dir', type=str, required=True,
                      help='The directory where to put intermediate files')
  parser.add_argument('--app-dir', type=str, required=True,
                      help='The root of the app')
  parser.add_argument('--packages', type=str, required=True,
                      help='The package map to use')
  parser.add_argument('--manifest', type=str, help='The application manifest')
  parser.add_argument('--asset-manifest-out', type=str,
                      help='Output path for the asset manifest used by the fuchsia packaging tool')

  args = parser.parse_args()

  env = os.environ.copy()
  env['FLUTTER_ROOT'] = args.flutter_root

  call_args = [
    args.flutter_tools,
    '--working-dir=%s' % args.working_dir,
    '--packages=%s' % args.packages,
  ]
  if 'manifest' in args:
    call_args.append('--manifest=%s' % args.manifest)

  if args.asset_manifest_out != None:
    call_args.append('--asset-manifest-out=%s' % args.asset_manifest_out)

  result = subprocess.call(call_args, env=env, cwd=args.app_dir)

  return result

if __name__ == '__main__':
  sys.exit(main())
