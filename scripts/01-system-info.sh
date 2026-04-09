#!/bin/bash

echo "=== System Information ==="
echo "Date: $(date)"
echo ""

echo "--- CPU ---"
if [ -f /proc/cpuinfo ]; then
    grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs
    grep "cpu cores" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs
    grep "siblings" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs
fi

echo ""
echo "--- Memory ---"
if command -v free &> /dev/null; then
    free -h
fi

echo ""
echo "--- Disk ---"
df -h / | tail -1
if [ -f /sys/block/nvme0n1/queue/rotational ]; then
    if [ "$(cat /sys/block/nvme0n1/queue/rotational)" = "0" ]; then
        echo "Type: NVMe SSD"
    else
        echo "Type: HDD"
    fi
fi

echo ""
echo "--- Kernel ---"
uname -a

echo ""
echo "--- Node.js ---"
node --version
npm --version