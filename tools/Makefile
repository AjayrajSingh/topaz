# Copyright 2016 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

root := $(shell git rev-parse --show-toplevel)

# Change to suit the project location.
fuchsia_root := $(realpath $(root)/../..)

common_root := $(realpath $(fuchsia_root)/topaz/tools/tools/common)
common_makefile := $(realpath $(common_root)/Makefile)

# The project variable is the path of this project, relative to //topaz.
PROJECT := tools

include $(common_makefile)


################################################################################
## Project specific build
.PHONY: build-override
build-override:
	@true
