# Copyright 2017 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

root := $(shell git rev-parse --show-toplevel)
fuchsia_root ?= $(shell jiri -show-root)

scripts_dir := $(realpath $(fuchsia_root)/topaz/tools/scripts)
common_makefile := $(realpath $(scripts_dir)/Makefile)

# The project variable is the path of this project, relative to //topaz.
PROJECT := shell/mondrian_story_shell

include $(common_makefile)


################################################################################
## Project specific build
.PHONY: build-override
build-override:
	@true
