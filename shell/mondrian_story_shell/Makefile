# Copyright 2017 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

root := $(shell git rev-parse --show-toplevel)
fuchsia_root := $(realpath $(root)/../..)
common_root := $(realpath $(fuchsia_root)/apps/modules/common/tools/common)
common_makefile := $(realpath $(common_root)/Makefile)

# Assumes that the project is located three levels deep in the Fuchsia tree,
# specifically: $FUCHSIA_DIR/apps/modules/<project>.
PROJECT := ../mondrian
FUCHSIA_TARGET := mondrian

include $(common_makefile)


################################################################################
## Project specific build
.PHONY: build-override
build-override:
	@true
