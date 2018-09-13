#!/usr/bin/env bash
# Copyright 2017 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -eu

# Prebuilts are specified by both the revision of //third_party/webkit and the
# topaz jiri.snapshot file hash.
# To find the latest PREBUILT_SUBPATH value:
# - Go to the latest successful build of
#   https://ci.chromium.org/p/fuchsia/builders/luci.fuchsia.ci/web_view-linux.
# - Find any "webkit.so" link on the page.
# - Use the trailing part of the link's URL as the new PREBUILT_SUBPATH.
readonly PREBUILT_SUBPATH="4de3d0194d6a3796161a4b0fc9f473bb273a8034/15339d44de8bea48042c4c2ee12f9abd27f4d6b9/libwebkit.so"

readonly SCRIPT_ROOT="$(cd $(dirname ${BASH_SOURCE[0]} ) && pwd)"
readonly FUCHSIA_ROOT="${SCRIPT_ROOT}/../../../.."
. "${FUCHSIA_ROOT}/buildtools/download.sh"

readonly URL_BASE="https://storage.googleapis.com/fuchsia"
readonly DOWNLOAD_PATH_BASE="${SCRIPT_ROOT}/../prebuilt"

function download_webkit_for_arch() {
    local arch="${1}"

    local download_path="${DOWNLOAD_PATH_BASE}/${arch}"
    local stamp_file="${download_path}/libwebkit.stamp"
    local url="${URL_BASE}/${arch}/webkit/${PREBUILT_SUBPATH}"
    local target_path="${DOWNLOAD_PATH_BASE}/${arch}/libwebkit.so"

    if [[ ! -f "${download_path}" ]]; then
        mkdir -p "${download_path}"
    fi

    if [[ ! -f "${stamp_file}" ]] || [[ "${url}" != $(cat "${stamp_file}") ]]; then
        echo "Downloading ${arch}/libwebkit.so..."
        download "${url}" "${target_path}"
        echo "${url}" > "${stamp_file}"
    fi
}

download_webkit_for_arch "x86_64"
download_webkit_for_arch "aarch64"
