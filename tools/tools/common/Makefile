# Copyright 2017 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

MAKEFLAGS += --warn-undefined-variables --no-print-directory
SHELL := /bin/bash

.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

# This Makefile is expected to be included in a parent Makefile for a given
# project. In order for the conventions used by the tasks defined in this file
# a PROJECT, FLUTTER_TARGET, and FUCHSIA_TARGET variables must be set, for
# example:
#
#     PROJECT := email
#     FLUTTER_TARGET := modules/story
#     FUCHSIA_TARGET := email_story
#
#     include <path to this Makefile>
#
ifndef PROJECT
$(error PROJECT is not set. \
Before including the common Makefile add "PROJECT := <project>" to \
"$(firstword $(realpath $(MAKEFILE_LIST)))")
endif

ifndef FLUTTER_TARGET
$(error FLUTTER_TARGET is not set. \
Before including the common Makefile add "FLUTTER_TARGET := <target>" variable to \
"$(firstword $(realpath $(MAKEFILE_LIST)))")
endif

ifndef FUCHSIA_TARGET
$(error PROJECT is not set. \
Before including the common Makefile add "FUCHSIA_TARGET := <target>" to \
"$(firstword $(realpath $(MAKEFILE_LIST)))")
endif

root ?= $(shell git rev-parse --show-toplevel)
fuchsia_root ?= $(realpath $(root)/../../..)
common_root ?= $(realpath $(fuchsia_root)/apps/modules/common/tools/common)
tools_root := $(realpath $(common_root)/..)
fuchsia_out := $(realpath $(fuchsia_root)/out)
flutter_root := $(fuchsia_root)/lib/flutter
flutter_bin := $(flutter_root)/bin
dart_bin := $(flutter_bin)/cache/dart-sdk/bin

flutter := $(flutter_bin)/flutter
dart := $(dart_bin)/dart
pub := $(dart_bin)/pub

ignored_dirs := _book generated infra node_modules testdata
ignore_flags := $(shell echo $(addprefix '! -wholename "*/',$(addsuffix '/*"',$(ignored_dirs))))
sfind := find $(root) $(ignore_flags)

dart_sources := $(shell $(sfind) -name "*.dart")

dart_packages := $(shell $(sfind) -name "pubspec.yaml" -exec dirname {} \;)

sources := $(shell $(sfind) \
	-name "*.dart" \
	-o -name "*.py" \
	-o -name "*.fidl" \
	-o -name "*.gn" \
	-o -name "*.sh" \
	-o -name "*.yaml")

makefiles := $(foreach file, $(MAKEFILE_LIST), $(realpath $(file)))

PATH := $(flutter_bin):$(dart_bin):$(PATH)

.PHONY: all
all: build

.PHONY: build
build: ## Build Fuchsia with project.
	@FUCHSIA_DIR=$(fuchsia_root) $(common_root)/build.sh

.PHONY: clean
clean: dart-clean ## Clean build artifacts from this project.

.PHONY: reboot
reboot: ## Reboot connected Fuchsia device.
	@FUCHSIA_DIR=$(fuchsia_root) $(common_root)/reboot.sh

.PHONY: run
run: ## Run project on Fuchsia.
	@echo "=== Don't forget to reboot between builds! ==="
	@FUCHSIA_DIR=$(fuchsia_root) $(common_root)/run.sh $(FUCHSIA_TARGET)

.PHONY: flutter-run
flutter-run: ## Run UI application in modules/<project> via `flutter run`.
	cd $(FLUTTER_TARGET) && \
		$(flutter) packages upgrade && \
		$(flutter) build clean && \
		$(flutter) run --hot

.PHONY: fmt
fmt: dart-fmt ## Format the code in this project.

.PHONY: test
test: dart-test ## Run the tests in this project.

.PHONY: coverage
coverage: dart-coverage ## Show coverage for this project.

.PHONY: presubmit
presubmit: build lint test ## Run the presubmit tests for this project.

.PHONY: presubmit-cq
presubmit-cq: build lint

.PHONY: lint
lint: copyright-check dart-lint dart-fmt-check ## Lint the code.

%/.packages: %/pubspec.yaml
	@cd $* && flutter packages get

.PHONY: $(dart_bin)
$(dart_bin):
	@$(flutter) precache

.PHONY: dart-clean
dart-clean:
	@# Remove all build artifacts, including the coverage information.
	@# Also, if there is a pubspec.lock file that is not tracked by git, remove
	@# it as well.
	@for pkg in $(dart_packages); do \
		pushd $${pkg} > /dev/null; \
		rm -rf .packages packages .pub build coverage; \
		git ls-files pubspec.lock --error-unmatch &> /dev/null; \
		if [ $$? -ne 0 ]; then \
			rm -f pubspec.lock; \
		fi; \
		popd > /dev/null; \
	done
	@rm -rf coverage

.PHONY: dart-lint
dart-lint: build
	@$(fuchsia_root)/scripts/run-dart-analysis.py \
			--out=$(fuchsia_out)/debug-x86-64 \
			--tree=//apps/modules/$(PROJECT)/* \
			--lints --fatal-lints --fatal-warnings

.PHONY: dart-fmt
dart-fmt: $(dart_bin) $(tools_root)/dartfmt_extras/.packages
	@dartfmt -w $(dart_sources)
	@cd $(tools_root)/dartfmt_extras; \
	FLUTTER_ROOT=$(flutter_root) $(pub) run bin/main.dart fix / $(dart_sources)

.PHONY: dart-fmt-check
dart-fmt-check: $(dart_bin) $(tools_root)/dartfmt_extras/.packages
	@dartfmt --dry-run --set-exit-if-changed $(dart_sources); \
	error=$$?; \
	cd $(tools_root)/dartfmt_extras; \
	FLUTTER_ROOT=$(flutter_root) $(pub) run bin/main.dart check / $(dart_sources); \
	if [ $$? -ne 0 -o $$error -ne 0 ] ; then \
		echo; \
		echo "The above dart files have formatting issues."; \
		echo "Run \"make fmt\" to fix the formatting."; \
		echo; \
		exit 1; \
	fi

.PHONY: dart-test
dart-test: $(dart_bin)
	@$(common_root)/run_dart_tests.py

.PHONY: dart-coverage
dart-coverage: $(dart_bin)
	@$(common_root)/run_dart_tests.py --coverage
	@$(common_root)/merge_coverage.sh
	@$(dart) $(common_root)/report_coverage.dart coverage/lcov.info

.PHONY: copyright-check
copyright-check: ## Check source files for missing copyright.
	@$(common_root)/copyright-check.sh $(sources)

.PHONY: help
help: ## Displays this help message.
	@for file in $(makefiles); do \
		grep -E '^[a-zA-Z_-]+:.*?## .*$$' $${file} | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "%-20s %s\n", $$1, $$2}'; \
	done
