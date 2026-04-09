#!/bin/bash

set -e

OUTPUT_DIR="${1:-/root/test/output}"
BUILD_PID="$2"
INTERVAL="${3:-1}"

mkdir -p "$OUTPUT_DIR"

CPU_FILE="$OUTPUT_DIR/cpu-metrics.json"
MEM_FILE="$OUTPUT_DIR/mem-metrics.json"
DISK_FILE="$OUTPUT_DIR/disk-metrics.json"

echo "[]" > "$CPU_FILE"
echo "[]" > "$MEM_FILE"
echo "[]" > "$DISK_FILE"

start_time=$(date +%s)

monitor_resources() {
    while true; do
        current_time=$(date +%s.%N)
        timestamp=$(date -Iseconds)
        
        if [ -n "$BUILD_PID" ] && kill -0 "$BUILD_PID" 2>/dev/null; then
            cpu_usage=$(ps -p "$BUILD_PID" -o %cpu= 2>/dev/null || echo "0")
            mem_usage=$(ps -p "$BUILD_PID" -o rss= 2>/dev/null || echo "0")
        else
            cpu_usage="0"
            mem_usage="0"
        fi
        
        total_cpu=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
        mem_available=$(free -m | awk '/Mem:/ {print $7}')
        mem_used=$(free -m | awk '/Mem:/ {print $3}')
        mem_total=$(free -m | awk '/Mem:/ {print $2}')
        
        read_bytes=0
        write_bytes=0
        if [ -f /proc/diskstats ]; then
            read_bytes=$(cat /proc/diskstats | awk '{sum += $6} END {print sum * 512}')
            write_bytes=$(cat /proc/diskstats | awk '{sum += $10} END {print sum * 512}')
        fi
        
        cpu_entry=$(cat <<EOF
{"timestamp": "$timestamp", "total_cpu": $total_cpu, "build_process_cpu": $cpu_usage}
EOF
)
        mem_entry=$(cat <<EOF
{"timestamp": "$timestamp", "used_mb": $mem_used, "available_mb": $mem_available, "total_mb": $mem_total, "build_process_rss_kb": $mem_usage}
EOF
)
        disk_entry=$(cat <<EOF
{"timestamp": "$timestamp", "read_bytes": $read_bytes, "write_bytes": $write_bytes}
EOF
)
        
        temp_cpu=$(mktemp)
        temp_mem=$(mktemp)
        temp_disk=$(mktemp)
        
        sed -i 's/]$/,/; s/$/]/' "$CPU_FILE" 2>/dev/null || true
        sed -i 's/]$/,/; s/$/]/' "$MEM_FILE" 2>/dev/null || true
        sed -i 's/]$/,/; s/$/]/' "$DISK_FILE" 2>/dev/null || true
        
        head -c -1 "$CPU_FILE" > "$temp_cpu" 2>/dev/null || echo "[" > "$temp_cpu"
        echo "$cpu_entry]" >> "$temp_cpu"
        mv "$temp_cpu" "$CPU_FILE"
        
        head -c -1 "$MEM_FILE" > "$temp_mem" 2>/dev/null || echo "[" > "$temp_mem"
        echo "$mem_entry]" >> "$temp_mem"
        mv "$temp_mem" "$MEM_FILE"
        
        head -c -1 "$DISK_FILE" > "$temp_disk" 2>/dev/null || echo "[" > "$temp_disk"
        echo "$disk_entry]" >> "$temp_disk"
        mv "$temp_disk" "$DISK_FILE"
        
        sleep "$INTERVAL"
    done
}

monitor_resources &
MONITOR_PID=$!

echo "Monitor started with PID: $MONITOR_PID"
echo "$MONITOR_PID" > "$OUTPUT_DIR/monitor.pid"

wait $BUILD_PID
BUILD_EXIT=$?

kill $MONITOR_PID 2>/dev/null || true
wait $MONITOR_PID 2>/dev/null || true

echo "Monitoring stopped. Build exited with code: $BUILD_EXIT"
exit $BUILD_EXIT