#!/bin/bash
# Copyright 2018 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

cd $(dirname $0)

echo Testing extract-zircon-constants.py
exec python ../../../topaz/public/dart/zircon/extract-zircon-constants.py -n
