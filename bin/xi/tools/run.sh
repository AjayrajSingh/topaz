#!/bin/bash
# Copyright 2017 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Exit this script if one command fails.
set -e

fx shell "bootstrap device_runner --user-shell=dev_user_shell --user-shell-args=--root-module=xi_app"
