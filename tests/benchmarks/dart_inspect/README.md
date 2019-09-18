# Dart inspect benchmarks

This directory contains the code to the inspect benchmarks, written in dart.

# Modifying the `.tspec` file

The [`basic_benchmarks.tspec`](basic_benchmarks.tspec) file contains the definition of the
benchmark tests.  When adding a new benchmark, one needs to change this file to ensure that
the results are used in any analysis frameworks.

Please do not change the `output_test_name` for existing tests if you can help it, since that
is the identifier used to match up previous test results to current ones.

The `duration` parameter in the `.tspec` file is the amount of time, expressed in seconds, that the
benchmark should run for.  The benchmark will stop early if the duration expires before the 
benchmark code completed execution.

# Helpful scripts

Here are a few helpful scripts that show how one can automate running the dart inspect benchmarks,
starting from a setup where you have a device that supports UI tests.

First script is `fx.sb`:

```bash
#! /bin/bash
set -x
set -euo pipefail
BASE_PACKAGES=(
  //topaz/packages:buildbot
)
PACKAGES=(
  //garnet/bin/ui/tests/performance/vulkan_is_supported
  //garnet/packages/benchmarks:buildbot
  //garnet/packages/products:devtools
  //topaz/packages:buildbot
  //topaz/tests/benchmarks:all
  //topaz/tests/benchmarks:all
  //topaz/tests/benchmarks/dart_inspect:dart_inspect_benchmarks
)
PUSH_PACKAGES="${PUSH_PACKAGES:-}"

PRODUCT="${PRODUCT:-workstation.chromebook-x64}"

cd "${FUCHSIA_DIR}"
fx \
  --dir out/release \
  set "${PRODUCT}" \
  --release \
  --variant clang \
  --with-base="$(echo ${BASE_PACKAGES[@]} | sed -e 's/ /,/g')" \
  --with="$(echo ${PACKAGES[@]} | sed -e 's/ /,/g')"
time fx build
fx compdb && perl -pi -e 's|/[/\w]+/gomacc ||' compile_commands.json
```

Second script is `fx.perf`:

```bash
#! /bin/bash
set -euox pipefail
fx build-push topaz_benchmarks vulkan_is_supported topaz_input_latency_benchmarks dart_inspect_benchmarks
CMD=(
  /pkgfs/packages/topaz_benchmarks/0/bin/benchmarks.sh /tmp
  --catapult-converter-args
  --bots topaz-x64-perf-dawson_canyon
  --masters fuchsia.try
  --execution-timestamp-ms 1534438419097
  --log-url https://fake_url
)
fx shell "${CMD[@]}"
```

To set and build everything one can then do:

```bash
$ ./fx.sb
```

Once done with setting and building, which may take a while if done for the first time, you
can run the performance benchmarks like this:

```bash
$ ./fx.perf
```

