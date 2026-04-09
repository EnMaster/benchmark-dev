#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"

INTENSITY="${1:-medium}"
NUM_RUNS="${2:-1}"

declare -A INTENSITY_SETTINGS=(
    [low_modules]=100
    [low_files]=3
    [medium_modules]=500
    [medium_files]=10
    [high_modules]=1000
    [high_files]=20
)

NUM_MODULES="${INTENSITY_SETTINGS[${INTENSITY}_modules]}"
NUM_FILES="${INTENSITY_SETTINGS[${INTENSITY}_files]}"

OUTPUT_DIR="$ROOT_DIR/output"
PROJECT_DIR="$ROOT_DIR/heavy-project"
BENCHMARK_LOG="$OUTPUT_DIR/benchmark.log"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$PROJECT_DIR"

echo "=============================================="
echo "     Node.js Build Benchmark System"
echo "=============================================="
echo "Intensity: $INTENSITY"
echo "Modules: $NUM_MODULES"
echo "Files per module: $NUM_FILES"
echo "Runs: $NUM_RUNS"
echo "Output: $OUTPUT_DIR"
echo "=============================================="

echo "$(date)" > "$BENCHMARK_LOG"
echo "Starting benchmark with intensity: $INTENSITY" >> "$BENCHMARK_LOG"

SCRIPTS_DIR="$SCRIPT_DIR/scripts"

echo ""
echo "[1/5] Collecting system information..."
bash "$SCRIPTS_DIR/01-system-info.sh" | tee "$OUTPUT_DIR/system-info.txt"

echo ""
echo "[2/5] Generating heavy Node.js project..."
start_gen=$(date +%s)
bash "$SCRIPTS_DIR/02-generate-project.sh" "$ROOT_DIR" "$NUM_MODULES" "$NUM_FILES" 2>&1 | tee -a "$BENCHMARK_LOG"
end_gen=$(date +%s)
gen_duration=$((end_gen - start_gen))
echo "Project generation took: ${gen_duration}s" | tee -a "$BENCHMARK_LOG"

echo ""
echo "[3/5] Installing dependencies..."
start_install=$(date +%s)
cd "$PROJECT_DIR"
npm install --prefer-offline 2>&1 | tee -a "$BENCHMARK_LOG"
end_install=$(date +%s)
install_duration=$((end_install - start_install))
echo "Dependency installation took: ${install_duration}s" | tee -a "$BENCHMARK_LOG"

echo ""
echo "[4/5] Starting build with monitoring..."
start_build=$(date +%s)

# Start background monitoring
(
    cd "$PROJECT_DIR"
    while true; do
        timestamp=$(date -Iseconds)
        
        cpu_idle=$(vmstat 1 2 | tail -1 | awk '{print $15}')
        cpu_usage=$((100 - cpu_idle))
        
        mem_info=$(free -m | awk '/Mem:/ {print "used:"$3",free:"$4",available:"$7",cached:"$6}')
        
        disk_read=$(cat /proc/diskstats | awk '/nvme/ {sum += $6} END {print sum * 512}')
        disk_write=$(cat /proc/diskstats | awk '/nvme/ {sum += $10} END {print sum * 512}')
        
        echo "{\"timestamp\":\"$timestamp\",\"cpu\":$cpu_usage,\"memory\":\"$mem_info\",\"disk_read\":$disk_read,\"disk_write\":$disk_write}" >> "$OUTPUT_DIR/metrics.jsonl"
        
        sleep 1
    done
) &
MONITOR_PID=$!
echo "Monitor PID: $MONITOR_PID"

# Run the build
cd "$PROJECT_DIR"
npm run build 2>&1 | tee -a "$BENCHMARK_LOG"
BUILD_EXIT=$?

# Stop monitoring
kill $MONITOR_PID 2>/dev/null || true
wait $MONITOR_PID 2>/dev/null || true

end_build=$(date +%s)
build_duration=$((end_build - start_build))

echo "Build completed in: ${build_duration}s (exit code: $BUILD_EXIT)" | tee -a "$BENCHMARK_LOG"

if [ $BUILD_EXIT -ne 0 ]; then
    echo "WARNING: Build failed with exit code $BUILD_EXIT"
fi

echo ""
echo "[5/5] Generating report..."

# Parse metrics and generate summary
total_cpu=0
cpu_count=0
peak_cpu=0
peak_mem=0
total_disk_read=0
total_disk_write=0

if [ -f "$OUTPUT_DIR/metrics.jsonl" ]; then
    while IFS= read -r line; do
        cpu=$(echo "$line" | grep -o '"cpu":[0-9.]*' | cut -d: -f2)
        mem_used=$(echo "$line" | grep -o 'used:[0-9]*' | head -1 | cut -d: -f2)
        
        if [ -n "$cpu" ]; then
            total_cpu=$((total_cpu + cpu))
            cpu_count=$((cpu_count + 1))
            if [ "$cpu" -gt "$peak_cpu" ] 2>/dev/null; then
                peak_cpu=$cpu
            fi
        fi
        
        if [ -n "$mem_used" ] && [ "$mem_used" -gt "$peak_mem" ] 2>/dev/null; then
            peak_mem=$mem_used
        fi
    done < "$OUTPUT_DIR/metrics.jsonl"
fi

avg_cpu=$((cpu_count > 0 ? total_cpu / cpu_count : 0))

echo ""
echo "=============================================="
echo "           BENCHMARK RESULTS"
echo "=============================================="
echo "Intensity:           $INTENSITY"
echo "Project gen time:   ${gen_duration}s"
echo "Install time:       ${install_duration}s"
echo "Build time:         ${build_duration}s"
echo "Total time:         $((gen_duration + install_duration + build_duration))s"
echo ""
echo "Peak CPU usage:     ${peak_cpu}%"
echo "Avg CPU usage:      ${avg_cpu}%"
echo "Peak Memory (MB):   ${peak_mem}"
echo "Build exit code:    $BUILD_EXIT"
echo "=============================================="

cat > "$OUTPUT_DIR/summary.json" << EOF
{
  "benchmark": {
    "timestamp": "$(date -Iseconds)",
    "intensity": "$INTENSITY",
    "num_modules": $NUM_MODULES,
    "num_files_per_module": $NUM_FILES,
    "num_runs": $NUM_RUNS
  },
  "timing": {
    "project_generation_seconds": $gen_duration,
    "dependency_install_seconds": $install_duration,
    "build_seconds": $build_duration,
    "total_seconds": $((gen_duration + install_duration + build_duration))
  },
  "metrics": {
    "peak_cpu_percent": $peak_cpu,
    "avg_cpu_percent": $avg_cpu,
    "peak_memory_mb": $peak_mem,
    "build_exit_code": $BUILD_EXIT
  },
  "system": {
    "cpu_model": "$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)",
    "total_memory_mb": $(free -m | awk '/Mem:/ {print $2}'),
    "node_version": "$(node --version)",
    "npm_version": "$(npm --version)"
  }
}
EOF

echo ""
echo "Results saved to: $OUTPUT_DIR/"
ls -la "$OUTPUT_DIR/"
echo ""
echo "Benchmark complete!"