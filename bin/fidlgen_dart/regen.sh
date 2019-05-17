#!/usr/bin/env bash

if [ ! -x "${FUCHSIA_BUILD_DIR}" ]; then
    echo "error: did you fx exec? missing \$FUCHSIA_BUILD_DIR" 1>&2
    exit 1
fi

FIDLGEN="${FUCHSIA_BUILD_DIR}/host_x64/fidlgen_dart"
if [ ! -x "${FIDLGEN}" ]; then
    echo "error: fidlgen missing; maybe fx clean-build x64?" 1>&2
    exit 1
fi

DARTFMT="${FUCHSIA_DIR}/prebuilt/third_party/dart/linux-x64/bin/dartfmt"
if [ ! -x "${DARTFMT}" ]; then
    echo "error: dartfmt missing; did its location change? Looking in ${DARTFMT}" 1>&2
    exit 1
fi

EXAMPLE_DIR="$FUCHSIA_DIR/garnet/go/src/fidl/compiler/backend/goldens"
GOLDENS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/goldens"
GOLDENS=()
for json_name in `find "${EXAMPLE_DIR}" -name '*.json'`; do
    json_name="$( basename $json_name )"
    dart_sync_name=${json_name}_sync.dart.golden
    dart_async_name=${json_name}_async.dart.golden
    dart_test_name=${json_name}_test.dart.golden

    GOLDENS+=(
      $json_name,
      $dart_sync_name,
      $dart_async_name,
      $dart_test_name,
    )

    echo -e "\033[1mexample: ${json_name}\033[0m"
    cp "${EXAMPLE_DIR}/${json_name}" "${GOLDENS_DIR}/${json_name}"
    ${FIDLGEN} \
        -json "${GOLDENS_DIR}/${json_name}" \
        -output-base "${GOLDENS_DIR}" \
        -include-base "${GOLDENS_DIR}"
    mv "${GOLDENS_DIR}/fidl.dart" "${GOLDENS_DIR}/${dart_sync_name}"
    $DARTFMT -w "${GOLDENS_DIR}/${dart_sync_name}"
    mv "${GOLDENS_DIR}/fidl_async.dart" "${GOLDENS_DIR}/${dart_async_name}"
    $DARTFMT -w "${GOLDENS_DIR}/${dart_async_name}"
    mv "${GOLDENS_DIR}/fidl_test.dart" "${GOLDENS_DIR}/${dart_test_name}"
    $DARTFMT -w "${GOLDENS_DIR}/${dart_test_name}"
done

> "${GOLDENS_DIR}/goldens.txt"
printf "%s\n" "${GOLDENS[@]//,}" | sort >> "${GOLDENS_DIR}/goldens.txt"
