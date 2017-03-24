# Copyright 2016 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Assumes that the project is located three levels deep in the Fuchsia tree, for
# example: $FUCHSIA_DIR/apps/modules/<project>. Change to suit the project
# location.
root := $(shell git rev-parse --show-toplevel)
fuchsia_root := $(realpath $(root)/../../..)
common_root := $(realpath $(fuchsia_root)/apps/modules/common/tools/common)
common_makefile := $(realpath $(common_root)/Makefile)

PROJECT := common
FLUTTER_TARGET := gallery
FUCHSIA_TARGET := color # The common_makefile expects this variable to be set.

include $(common_makefile)


################################################################################
## Project specific build
.PHONY: build-override
build-override: dart-gen-specs $(addsuffix /.packages,$(filter-out $(dart_gn_packages),$(dart_all_packages)))
	@true


################################################################################
## Auth related targets
.PHONY: auth
auth: config.json ## Update email auth credentials with a refresh token.
	@cd tools/auth; \
	pub get; \
	pub run bin/oauth.dart
	@for dir in ../contacts/modules/contacts/assets gallery/assets modules/gallery/assets; do \
		mkdir -p $${dir}; \
		cp config.json $${dir}/config.json; \
	done

config.json:
	@echo "{}" >> config.json
	@echo "==> Config file added."
	@echo "==> Add missing values and run: make auth."


################################################################################
## Styleguide related targets

# To debug the generation process, pass in "--observe --pause-isolates-on-start"
# as the DART_FLAGS
dart_flags ?=
widget_package_dirs := $(realpath $(addprefix $(root)/, packages/widgets ../calendar/modules/calendar ../chat/modules/story ../contacts/modules/contacts))
widget_dot_packages := $(addsuffix /.packages, $(widget_package_dirs))

.PHONY: dart-gen-specs
dart-gen-specs: $(dart_bin) tools/widget_specs/.packages $(widget_dot_packages)
	@rm -rf gallery/lib/src/generated/*.dart
	@cd tools/widget_specs && \
	FLUTTER_ROOT=$(flutter_root) $(dart) $(dart_flags) bin/gen_widget_specs.dart \
		$(root)/gallery/lib/src/generated \
		$(widget_package_dirs)
	@rm -f $(widget_dot_packages)
