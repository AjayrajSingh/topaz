#!/usr/bin/env bash
# Copyright 2017 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -e

# This specifies the revision of //third_party/webkit to download prebuilts for. To roll, edit this
# hash to refer to a master commit in that repository.
readonly WEBKIT_REVISION="0960bec9f79f06122bdb9eebbde5b5e55fb1a259"

readonly SCRIPT_ROOT="$(cd $(dirname ${BASH_SOURCE[0]} ) && pwd)"
readonly FUCHSIA_ROOT="${SCRIPT_ROOT}/../../../.."
. "${FUCHSIA_ROOT}/buildtools/download.sh"

readonly URL_BASE="https://storage.googleapis.com/fuchsia"
readonly DOWNLOAD_PATH_BASE="${SCRIPT_ROOT}/../prebuilt"

function download_webkit_for_arch() {
    local arch="${1}"

    local download_path="${DOWNLOAD_PATH_BASE}/${arch}"
    local stamp_file="${download_path}/libwebkit.stamp"
    local url="${URL_BASE}/${arch}/webkit/${WEBKIT_REVISION}/libwebkit.so"
    local target_path="${DOWNLOAD_PATH_BASE}/${arch}/libwebkit.so"

    if [[ ! -f "${download_path}" ]]; then
        mkdir -p "${download_path}"
    fi

    if [[ ! -f "${stamp_file}" ]] || [[ "${WEBKIT_REVISION}" != $(cat "${stamp_file}") ]]; then
        echo "Downloading ${arch}/libwebkit.so..."
        download "${url}" "${target_path}"
        echo "${WEBKIT_REVISION}" > "${stamp_file}"
    fi
}

download_webkit_for_arch "x86_64"
download_webkit_for_arch "aarch64"
