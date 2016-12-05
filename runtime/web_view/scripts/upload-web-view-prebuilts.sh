#!/usr/bin/env bash

# Copyright 2016 The Fuchsia Authors
#
# Use of this source code is governed by a MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT

# This script uploads the prebuilts for the web view to Google Storage.

set -e
set -x

readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly WEBVIEW_PATH="$( cd "$SCRIPT_DIR/.." && pwd )"
readonly PREBUILTS_PATH="$WEBVIEW_PATH/prebuilt"
readonly PREBUILT_TAG=$(cat "${WEBVIEW_PATH}/prebuilt.tag" | tr -d '[[:space:]]')

: ${GOOGLE_CLOUD_SDK=$HOME/development/google-cloud-sdk} && export GOOGLE_CLOUD_SDK

readonly GS_BUCKET="gs://fuchsia-build/apps/web_view"
readonly GS_PATH="${GS_BUCKET}/prebuilt_${PREBUILT_TAG}.tar.gz"
readonly PREBUILTS_ARCHIVE=$WEBVIEW_PATH/prebuilt_$PREBUILT_TAG.tar.gz
COPYFILE_DISABLE=1 tar -C "$WEBVIEW_PATH" --exclude='.DS_Store' --exclude '._.*' -c -v -z -f "$PREBUILTS_ARCHIVE" prebuilt
echo "Uploading $PREBUILTS_ARCHIVE to ${GS_PATH}."
"$GOOGLE_CLOUD_SDK"/bin/gsutil cp "$PREBUILTS_ARCHIVE" ${GS_PATH}
rm "$PREBUILTS_ARCHIVE"