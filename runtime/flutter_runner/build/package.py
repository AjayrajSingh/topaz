#!/usr/bin/env python
# Copyright 2016 The Chromium Authors. All rights reserved.
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
  parser.add_argument('--snapshot', type=str, required=False,
                      help='Path to application snapshot')
  parser.add_argument('--dylib', type=str, required=False,
                      help='Path to AOT dylib')
  parser.add_argument('--output-file', type=str, required=True,
                      help='Where to output application bundle')
  parser.add_argument('--build-root', type=str, required=True,
                      help='The build\'s root directory')
  parser.add_argument('--depfile', type=str, required=True,
                      help='Where to output application bundle dependencies')
  parser.add_argument('--interpreter', type=str, required=True,
                      help='')
  parser.add_argument('--manifest', type=str, help='The application manifest')

  args = parser.parse_args()

  env = os.environ.copy()
  env['FLUTTER_ROOT'] = args.flutter_root

  call_args = [
    args.flutter_tools,
    '--working-dir=%s' % args.working_dir,
    '--packages=%s' % args.packages,
    '--output-file=%s' % args.output_file,
    '--header=#!fuchsia %s' % args.interpreter,
    '--build-root=%s' % args.build_root,
    '--depfile=%s' % args.depfile,
  ]
  if args.snapshot != None:
    call_args.append('--snapshot=%s' % args.snapshot)
  if args.dylib != None:
    call_args.append('--dylib=%s' % args.dylib)
  if 'manifest' in args:
    call_args.append('--manifest=%s' % args.manifest)

  result = subprocess.call(call_args, env=env, cwd=args.app_dir)

  return result


if __name__ == '__main__':
  sys.exit(main())
