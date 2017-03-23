#!/usr/bin/env bash

# Copyright 2017 The Fuchsia Authors
#
# Use of this source code is governed by a MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT

# This script uploads the web view to Google Storage.
# FUCHSIA_DIR and FUCHSIA_BUILD_DIR come from fuchsia/scripts/env.sh's fset
# command.

set -e
set -x

readonly WEBVIEW_PATH="$FUCHSIA_DIR/apps/web_view"
readonly EXECUTABLE_PATH="$FUCHSIA_BUILD_DIR/web_view"
readonly PREBUILT_TAG=$(cat "${WEBVIEW_PATH}/prebuilt.tag" | tr -d '[[:space:]]')

: ${GOOGLE_CLOUD_SDK=$HOME/development/google-cloud-sdk} && export GOOGLE_CLOUD_SDK

readonly GS_BUCKET="gs://fuchsia-build/apps/web_view"
readonly GS_PATH="${GS_BUCKET}/web_view_${PREBUILT_TAG}"
echo "Uploading $EXECUTABLE_PATH to ${GS_PATH}."
"$GOOGLE_CLOUD_SDK"/bin/gsutil cp "$EXECUTABLE_PATH" ${GS_PATH}
