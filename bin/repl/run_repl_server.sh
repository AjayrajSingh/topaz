#!/boot/bin/sh
# Copyright 2018 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -o errexit

# In the event of previous failures from other scripts or other components using
# the GPU, ensure that all components using the display have been shut down.
killall basemgr* || true
killall root_presenter* || true
killall scenic* || true

# TODO(bgoldman): Create a separate test instead of driver_example_mod_target_tests
run_test \
  basemgr --test --enable_presenter \
  --account_provider=dev_token_manager \
  --base_shell=dev_base_shell \
  --base_shell_args=--test_timeout_ms=3600000 \
  --user_shell=dev_user_shell \
  --user_shell_args=--root_module=test_driver_module,--module_under_test_url=driver_example_mod_wrapper,--test_driver_url=driver_example_mod_target_tests \
  --story_shell=dev_story_shell
