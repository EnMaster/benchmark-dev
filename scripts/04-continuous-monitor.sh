#!/bin/bash

set -e

OUTPUT_DIR="${1:-/root/test/output}"
SAMPLE_INTERVAL="${2:-1}"
DURATION="${3:-300}"

mkdir -p "$OUTPUT_DIR"

CPU_LOG="$OUTPUT_DIR/cpu.log"
MEM_LOG="$OUTPUT_DIR/mem.log"
DISK_LOG="$OUTPUT_DIR/disk.log"

> "$CPU_LOG"
> "$MEM_LOG"
> "$DISK_LOG"

echo "timestamp,cpu_user,cpu_sys,cpu_idle,cpu_iowait,mem_used_mb,mem_free_mb,mem_available_mb,mem_cached_mb,swap_used_mb" > "$MEM_LOG"
echo "timestamp,device,read_kb_per_sec,write_kb_per_sec,read_ops_per_sec,write_ops_per_sec" > "$DISK_LOG"

if command -v vmstat &> /dev/null; then
    vmstat -n 1 > "$CPU_LOG" 2>&1 &
    VMSTAT_PID=$!
fi

if command -v iostat &> /dev/null; then
    iostat -x 1 > "$DISK_LOG" 2>&1 &
    IOSTAT_PID=$!
fi

FREE_PID=""
while true; do
    timestamp=$(date +%s)
    free_output=$(free -m)
    
    mem_used=$(echo "$free_output" | awk '/Mem:/ {print $3}')
    mem_free=$(echo "$free_output" | awk '/Mem:/ {print $4}')
    mem_available=$(echo "$free_output" | awk '/Mem:/ {print $7}')
    mem_cached=$(echo "$free_output" | awk '/Mem:/ {print $6}')
    swap_used=$(echo "$free_output" | awk '/Swap:/ {print $3}')
    
    echo "$timestamp,$mem_used,$mem_free,$mem_available,$mem_cached,$swap_used" >> "$MEM_LOG"
    
    sleep "$SAMPLE_INTERVAL"
done &
FREE_PID=$!

echo "Monitoring started (PID: $FREE_PID)"
echo $FREE_PID > "$OUTPUT_DIR/monitor.pid"
echo $VMSTAT_PID > "$OUTPUT_DIR/vmstat.pid"
echo $IOSTAT_PID > "$OUTPUT_DIR/iostat.pid"

if [ -n "$DURATION" ]; then
    sleep "$DURATION"
    kill $FREE_PID $VMSTAT_PID $IOSTAT_PID 2>/dev/null || true
fi