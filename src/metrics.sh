#!/bin/bash

MONITOR_PID=""
MONITOR_LOG=""
CPU_SAMPLES=()
RAM_SAMPLES=()
START_TIME=""

start_monitoring() {
    MONITOR_LOG=$(mktemp)
    CPU_SAMPLES=()
    RAM_SAMPLES=()
    START_TIME=$(date +%s.%N)

    (
        while kill -0 $$ 2>/dev/null; do
            if [ -f /proc/stat ]; then
                local cpu=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
                local mem=$(free -m 2>/dev/null | grep Mem | awk '{print $3}')
                echo "CPU:$cpu" >> "$MONITOR_LOG"
                echo "MEM:$mem" >> "$MONITOR_LOG"
            elif command -v vm_stat &>/dev/null; then
                local cpu=$(top -l 1 -n 0 | grep "CPU usage" | awk '{gsub(/%/,""); print $3}')
                echo "CPU:$cpu" >> "$MONITOR_LOG"
            fi
            sleep 1
        done
    ) &
    MONITOR_PID=$!
}

stop_monitoring() {
    local end_time=$(date +%s.%N)

    if [ -n "$MONITOR_PID" ]; then
        kill $MONITOR_PID 2>/dev/null
        wait $MONITOR_PID 2>/dev/null
    fi

    local duration=$(echo "$end_time - $START_TIME" | bc 2>/dev/null || echo "0")

    if [ -f "$MONITOR_LOG" ]; then
        local cpu_avg=$(grep "^CPU:" "$MONITOR_LOG" | sed 's/CPU://' | awk '{sum+=$1; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}')
        local cpu_max=$(grep "^CPU:" "$MONITOR_LOG" | sed 's/CPU://' | awk '{if($1>max) max=$1} END {printf "%.1f", max}')
        local mem_avg=$(grep "^MEM:" "$MONITOR_LOG" | sed 's/MEM://' | awk '{sum+=$1; count++} END {if(count>0) printf "%.0f", sum/count; else print "0"}')

        echo "$cpu_avg|$cpu_max|$mem_avg|$duration"
    else
        echo "0|0|0|0"
    fi

    rm -f "$MONITOR_LOG"
}

get_load_average() {
    if [ -f /proc/loadavg ]; then
        cat /proc/loadavg
    elif command -v uptime &>/dev/null; then
        uptime | awk -F'load average:' '{print $2}'
    else
        echo "N/A"
    fi
}

measure_command() {
    local cmd="$1"
    local workdir="$2"

    start_monitoring

    local start=$(date +%s.%N)
    eval "cd '$workdir' && $cmd" 
    local exit_code=$?
    local end=$(date +%s.%N)

    local result=$(stop_monitoring)
    local cpu_avg=$(echo "$result" | cut -d'|' -f1)
    local cpu_max=$(echo "$result" | cut -d'|' -f2)
    local mem_avg=$(echo "$result" | cut -d'|' -f3)
    local duration=$(echo "$result" | cut -d'|' -f4)

    if [ -z "$duration" ] || [ "$duration" = "0" ]; then
        duration=$(echo "$end - $start" | bc 2>/dev/null || echo "1")
    fi

    echo "$cpu_avg|$cpu_max|$mem_avg|$duration|$exit_code"
}

get_system_info() {
    SYSINFO_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "4")
    SYSINFO_MEM=$(free -h 2>/dev/null | grep Mem | awk '{print $2}' || echo "N/A")
    SYSINFO_KERNEL=$(uname -r)
    SYSINFO_OS=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || uname -s)

    echo "=== System Info ==="
    echo "CPU Cores: $SYSINFO_CORES"
    echo "Memory: $SYSINFO_MEM"
    echo "Kernel: $SYSINFO_KERNEL"
    echo "OS: $SYSINFO_OS"
}
