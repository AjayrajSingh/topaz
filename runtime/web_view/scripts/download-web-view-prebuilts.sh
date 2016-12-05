#!/usr/bin/env bash

# Copyright 2016 The Fuchsia Authors
#
# Use of this source code is governed by a MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT

set -e
set -x

readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly WEBVIEW_PATH="$( cd "$SCRIPT_DIR/.." && pwd )"
readonly PREBUILT_TAG=$(cat "${WEBVIEW_PATH}/prebuilt.tag" | tr -d '[[:space:]]')

# Called when something goes wrong.
panic () {
  echo "ERROR: WebView download-prebuilts: $1"
  rm -fr "${TEMP_DIR}"
  exit 99
}

# Download URL to file.  Panic if HTTP status != 200.
download_url () {
  if [ $# -ne 2 ]; then
    panic "download_url() takes two arguments: the source URL, and destination file."
  fi
  local HTTP_STATUS=$(curl -w "%{http_code}" --progress-bar -continue-at= --location "$1" --output "$2")
  if [ ${HTTP_STATUS} -ne 200 ]; then
    panic "download_url() failed with HTTP status ${HTTP_STATUS} when downloading $1"
  fi
}

readonly INSTALLED_TAG=$(cat "${WEBVIEW_PATH}/prebuilt.stamp" | tr -d '[[:space:]]')

if [ "${PREBUILT_TAG}" = "${INSTALLED_TAG}" ]; then
  exit 0
fi

readonly PREBUILTS_PATH="$WEBVIEW_PATH/prebuilt"
readonly PREBUILTS_ARCHIVE=$WEBVIEW_PATH/prebuilt_$PREBUILT_TAG.tar.gz

readonly GS_ROOT="https://fuchsia-build.storage.googleapis.com/apps/web_view"
readonly GS_URL="${GS_ROOT}/prebuilt_${PREBUILT_TAG}.tar.gz"

download_url "${GS_URL}" "$PREBUILTS_ARCHIVE"

cd "$WEBVIEW_PATH"
tar xvzf "$PREBUILTS_ARCHIVE"
rm "$PREBUILTS_ARCHIVE"

cp "${WEBVIEW_PATH}/prebuilt.tag" "${WEBVIEW_PATH}/prebuilt.stamp"