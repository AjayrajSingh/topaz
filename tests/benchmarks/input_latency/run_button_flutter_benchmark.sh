#!/boot/bin/sh
#
# Copyright 2019 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Usage: run_button_flutter_benchmark.sh             \
#          --out_file <benchmark output file path>   \
#          --benchmark_label <benchmark label>
echo "Starting!"

while [ "$1" != "" ]; do
  case "$1" in
    --out_file)
      OUT_FILE="$2"
      shift
      ;;
    --benchmark_label)
      BENCHMARK_LABEL="$2"
      shift
      ;;
    *)
      break
      ;;
  esac
  shift
done

TRACE_FILE="/tmp/trace-$(date +%Y-%m-%dT%H:%M:%S).json"

echo "== $BENCHMARK_LABEL: Killing processes..."
killall root_presenter* || true
killall scenic* || true
killall basemgr* || true
killall view_manager* || true
killall flutter* || true
killall set_root_view* || true

echo "== $BENCHMARK_LABEL: Starting app..."
 /bin/run -d fuchsia-pkg://fuchsia.com/basemgr#meta/basemgr.cmx \
   --base_shell=fuchsia-pkg://fuchsia.com/button_flutter#meta/button_flutter.cmx

# Wait for button_flutter to start.
sleep 3

(
  sleep 4

   # Each tap will be 75850/50 = 1517ms apart, drifting 0.33ms against regular
   # 60 Hz vsync intervals, while skipping 91 full vsync intervals (~1.5s).
   #
   # Experimentally, this is enough of an interval to ensure each tap is
   # executing completely independently.
  /bin/input --tap_event_count=50 --duration=75850 tap 500 500
) &

echo "== $BENCHMARK_LABEL: Tracing..."
echo $TRACE_FILE
trace record --categories=input,gfx,magma,flutter --duration=80 --buffer-size=12 --output-file=$TRACE_FILE

echo "== $BENCHMARK_LABEL: Processing trace..."
/pkgfs/packages/garnet_input_latency_benchmarks/0/bin/process_input_latency_trace  \
  -test_suite_name="${BENCHMARK_LABEL}"                                            \
  -benchmarks_out_filename="${OUT_FILE}" "${TRACE_FILE}"
