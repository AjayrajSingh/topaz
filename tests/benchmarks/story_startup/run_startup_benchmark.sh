#!/boot/bin/sh
#
# Usage: run_startup_benchmark.sh                   \
#          --out_dir <trace output dir>             \
#          --out_file <benchmark output file path>  \
#          --benchmark_label <benchmark label>      \
#          --cmd <cmd to benchmark>                 \
#          --flutter_app_name <flutter application name>
#

while [ "$1" != "" ]; do
  case "$1" in
    --out_dir)
      OUT_DIR="$2"
      shift
      ;;
    --out_file)
      OUT_FILE="$2"
      shift
      ;;
    --benchmark_label)
      BENCHMARK_LABEL="$2"
      shift
      ;;
    --cmd)
      CMD="$2"
      shift
      ;;
    --flutter_app_name)
      FLUTTER_APP_NAME="$2"
      shift
      ;;
    *)
      break
      ;;
  esac
  shift
done

DATE=`date +%Y-%m-%dT%H:%M:%S`
TRACE_FILE=$OUT_DIR/trace.$DATE.json

echo "== $BENCHMARK_LABEL: Killing processes..."
killall root_presenter*; killall scenic*; killall basemgr*
killall view_manager*; killall flutter*; killall set_root_view*

echo "== $BENCHMARK_LABEL: Tracing..."
echo $TRACE_FILE

trace record --categories=dart,flutter,ledger,modular,vfs --duration=10 \
  --buffer-size=12 --output-file=$TRACE_FILE $CMD

echo "== $BENCHMARK_LABEL: Processing trace..."
/pkgfs/packages/startup_benchmarks/0/bin/process_startup_trace  \
  -test_suite_name="${BENCHMARK_LABEL}"                         \
  -flutter_app_name="${FLUTTER_APP_NAME}"                       \
  -benchmarks_out_filename="${OUT_FILE}" "${TRACE_FILE}"
