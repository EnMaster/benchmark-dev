#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR

if [ -f "$HOME/.config/benchmark/src/config.sh" ]; then
    CONFIG_SRC_DIR="$HOME/.config/benchmark/src"
    WORKSPACE_DIR="$HOME/.benchmark"
else
    CONFIG_SRC_DIR="$SCRIPT_DIR/src"
    WORKSPACE_DIR="$SCRIPT_DIR"
fi
export WORKSPACE_DIR

source "$CONFIG_SRC_DIR/config.sh"
source "$CONFIG_SRC_DIR/metrics.sh"

print_usage() {
    cat << EOF
CPU Benchmark v1.0 - Strumento per misurare le performance CPU attraverso scenari reali di build.

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    (default)              Esegue i benchmark
    --install             Installa lo strumento nel sistema
    --help                Mostra questo messaggio

OPTIONS:
    -m, --mode MODE       Modalità: quick (1 iter) o full (3 iter) [default: full]
    -t, --threads NUM     Numero di thread [default: auto]
    -c, --cleanup         Pulisci cache tra i test [default: true]
    -o, --output FORMAT   Output: cli, json, csv, both [default: both]
    -p, --parallel        Esegui i 3 benchmark in parallelo [default: false]
    --skip-docker         Salta installazione e test Docker
    --skip-maven          Salta installazione e test Maven
    --skip-node           Salta installazione e test Node.js

INSTALL OPTIONS:
    --install             Installa benchmark in /usr/local/bin (richiede root)
    --install-user        Installa nella home utente (~/.local/bin)

ESEMPI:
    $0                      # Esegui tutti i benchmark
    $0 --mode quick         # Modalità veloce
    $0 -t 8                 # Usa 8 thread
    $0 -o json              # Solo output JSON
    $0 -p                   # Esegui benchmark in parallelo
    $0 --install            # Installa lo strumento
    $0 --skip-docker        # Skippa test Docker

EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install)
                INSTALL_MODE=true
                CONFIG_DIR="$HOME/.config/benchmark"
                export CONFIG_DIR
                do_install "/usr/local/bin"
                echo ""
                echo "Esegui: benchmark"
                echo "oppure: /usr/local/bin/benchmark"
                exit 0
                ;;
            --install-user)
                INSTALL_MODE=true
                CONFIG_DIR="$HOME/.config/benchmark"
                export CONFIG_DIR
                do_install "$HOME/.local/bin"
                echo ""
                echo "Esegui: benchmark"
                echo "oppure: $HOME/.local/bin/benchmark"
                exit 0
                ;;
            -m|--mode)
                MODE="$2"
                shift 2
                ;;
            -t|--threads)
                THREADS="$2"
                shift 2
                ;;
            -c|--cleanup)
                CLEANUP_CACHE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -p|--parallel)
                PARALLEL_MODE=true
                shift
                ;;
            --skip-docker)
                SKIP_DOCKER=true
                shift
                ;;
            --skip-maven)
                SKIP_MAVEN=true
                shift
                ;;
            --skip-node)
                SKIP_NODE=true
                shift
                ;;
            -h|--help)
                print_usage
                ;;
            *)
                echo "Opzione sconosciuta: $1"
                print_usage
                ;;
        esac
    done
}

init_results() {
    mkdir -p "$RESULTS_DIR"
    : > "$LOG_FILE"
    : > "$JSON_FILE"
    : > "$CSV_FILE"

    cat > "$JSON_FILE" << 'EOF'
{
  "timestamp": "",
  "system": {
    "cores": 0,
    "threads": 0,
    "memory": "",
    "os": ""
  },
  "benchmarks": {}
}
EOF

    cat > "$CSV_FILE" << 'EOF'
benchmark,time_s,cpu_avg,cpu_max,memory_mb
EOF
}

update_json() {
    local key="$1"
    local time="$2"
    local cpu_avg="$3"
    local cpu_max="$4"

    [ -f "$CONFIG_SRC_DIR/metrics.sh" ] && source "$CONFIG_SRC_DIR/metrics.sh" 2>/dev/null

    local temp=$(mktemp)
    jq --arg key "$key" \
       --arg time "$time" \
       --arg cpu_avg "$cpu_avg" \
       --arg cpu_max "$cpu_max" \
       --arg cores "${SYSINFO_CORES:-$NUM_CORES}" \
       --arg threads "${THREADS}" \
       --arg memory "${SYSINFO_MEM:-N/A}" \
       --arg os "${SYSINFO_OS:-N/A}" \
       '.timestamp = now | .system.cores = ($cores | tonumber) | .system.threads = ($threads | tonumber) | .system.memory = $memory | .system.os = $os | .benchmarks[$key] = {"time": ($time | tonumber), "cpu_avg": ($cpu_avg | tonumber), "cpu_max": ($cpu_max | tonumber)}' \
       "$JSON_FILE" > "$temp"
    mv "$temp" "$JSON_FILE"
}

update_csv() {
    local name="$1"
    local time="$2"
    local cpu_avg="$3"
    local cpu_max="$4"
    echo "$name,$time,$cpu_avg,$cpu_max,0" >> "$CSV_FILE"
}

print_results() {
    local name="$1"
    local time="$2"
    local cpu_avg="$3"
    local cpu_max="$4"

    echo ""
    echo -e "${COLOR_BLUE}[${name}]${COLOR_NC}"
    echo "  Tempo:     ${time}s"
    echo "  CPU media: ${cpu_avg}%"
    echo "  CPU max:   ${cpu_max}%"
}

run_benchmarks() {
    local mode_iterations=3
    [ "$MODE" = "quick" ] && mode_iterations=1

    log_info "Avvio benchmark in modalità: $MODE" "bench"
    log_info "Thread configurati: $THREADS" "bench"
    log_info "Iterazioni: $mode_iterations" "bench"
    [ "$PARALLEL_MODE" = "true" ] && log_info "Modalità PARALLELA attivata" "bench"

    get_system_info | tee -a "$LOG_FILE"

    export SYSINFO_CORES=$(nproc 2>/dev/null || echo "4")
    export SYSINFO_MEM=$(free -h 2>/dev/null | grep Mem | awk '{print $2}' || echo "N/A")
    export SYSINFO_OS=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || uname -s)

    if [ "$PARALLEL_MODE" = "true" ]; then
        run_parallel_benchmarks
    else
        run_sequential_benchmarks
    fi
}

run_sequential_benchmarks() {
    if [ "$SKIP_DOCKER" != "true" ]; then
        log_info "--- Benchmark 1: Docker Build ---" "bench"
        local docker_result=$(source "$CONFIG_SRC_DIR/docker_bench.sh" 2>&1)
        if echo "$docker_result" | grep -q "|"; then
            local name=$(echo "$docker_result" | tail -1 | cut -d'|' -f1)
            local time=$(echo "$docker_result" | tail -1 | cut -d'|' -f2)
            local cpu_avg=$(echo "$docker_result" | tail -1 | cut -d'|' -f3)
            local cpu_max=$(echo "$docker_result" | tail -1 | cut -d'|' -f4)
            [ -n "$time" ] && [ "$time" != "0" ] && update_json "docker_build" "$time" "$cpu_avg" "$cpu_max" && update_csv "docker_build" "$time" "$cpu_avg" "$cpu_max" && print_results "Docker Build" "$time" "$cpu_avg" "$cpu_max"
        fi
    else
        log_warn "Benchmark Docker saltato (--skip-docker)" "bench"
    fi

    if [ "$SKIP_MAVEN" != "true" ]; then
        log_info "--- Benchmark 2: Maven Build ---" "bench"
        local maven_result=$(source "$CONFIG_SRC_DIR/maven_bench.sh" 2>&1)
        if echo "$maven_result" | grep -q "|"; then
            local name=$(echo "$maven_result" | tail -1 | cut -d'|' -f1)
            local time=$(echo "$maven_result" | tail -1 | cut -d'|' -f2)
            local cpu_avg=$(echo "$maven_result" | tail -1 | cut -d'|' -f3)
            local cpu_max=$(echo "$maven_result" | tail -1 | cut -d'|' -f4)
            [ -n "$time" ] && [ "$time" != "0" ] && update_json "maven_build" "$time" "$cpu_avg" "$cpu_max" && update_csv "maven_build" "$time" "$cpu_avg" "$cpu_max" && print_results "Maven Build" "$time" "$cpu_avg" "$cpu_max"
        fi
    else
        log_warn "Benchmark Maven saltato (--skip-maven)" "bench"
    fi

    if [ "$SKIP_NODE" != "true" ]; then
        log_info "--- Benchmark 3: Node.js Build ---" "bench"
        local node_result=$(source "$CONFIG_SRC_DIR/node_bench.sh" 2>&1)
        if echo "$node_result" | grep -q "|"; then
            local name=$(echo "$node_result" | tail -1 | cut -d'|' -f1)
            local time=$(echo "$node_result" | tail -1 | cut -d'|' -f2)
            local cpu_avg=$(echo "$node_result" | tail -1 | cut -d'|' -f3)
            local cpu_max=$(echo "$node_result" | tail -1 | cut -d'|' -f4)
            [ -n "$time" ] && [ "$time" != "0" ] && update_json "node_build" "$time" "$cpu_avg" "$cpu_max" && update_csv "node_build" "$time" "$cpu_avg" "$cpu_max" && print_results "Node.js Build" "$time" "$cpu_avg" "$cpu_max"
        fi
    else
        log_warn "Benchmark Node.js saltato (--skip-node)" "bench"
    fi
}

run_parallel_benchmarks() {
    local temp_dir="$RESULTS_DIR/parallel_temp"
    mkdir -p "$temp_dir"

    log_info "=== Avvio benchmark in PARALLELO ===" "bench"

    local pids=()
    local docker_done=false maven_done=false node_done=false

    if [ "$SKIP_DOCKER" != "true" ]; then
        log_info ">>> Avvio Docker Build in background..." "bench"
        (
            source "$CONFIG_SRC_DIR/docker_bench.sh" 2>&1
        ) > "$temp_dir/docker.log" 2>&1 &
        pids+=($!)
    else
        docker_done=true
        log_warn "Benchmark Docker saltato (--skip-docker)" "bench"
    fi

    if [ "$SKIP_MAVEN" != "true" ]; then
        log_info ">>> Avvio Maven Build in background..." "bench"
        (
            source "$CONFIG_SRC_DIR/maven_bench.sh" 2>&1
        ) > "$temp_dir/maven.log" 2>&1 &
        pids+=($!)
    else
        maven_done=true
        log_warn "Benchmark Maven saltato (--skip-maven)" "bench"
    fi

    if [ "$SKIP_NODE" != "true" ]; then
        log_info ">>> Avvio Node.js Build in background..." "bench"
        (
            source "$CONFIG_SRC_DIR/node_bench.sh" 2>&1
        ) > "$temp_dir/node.log" 2>&1 &
        pids+=($!)
    else
        node_done=true
        log_warn "Benchmark Node.js saltato (--skip-node)" "bench"
    fi

    log_info "Attesa completamento benchmark (PID: ${pids[*]})..." "bench"

    for pid in "${pids[@]}"; do
        wait $pid 2>/dev/null
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            log_success "Benchmark PID $pid completato" "bench"
        else
            log_warn "Benchmark PID $pid completato con exit code $exit_code" "bench"
        fi
    done

    log_info "=== Raccolta risultati ===" "bench"

    for log in docker maven node; do
        local log_file="$temp_dir/${log}.log"
        if [ -f "$log_file" ]; then
            cat "$log_file" >> "$LOG_FILE"
            log_info "=== Log ${log} ===" "bench"
            tail -30 "$log_file" | while read line; do log_info "  $line" "bench"; done
        fi
    done

    if [ -f "$temp_dir/docker.log" ] && ! [ "$SKIP_DOCKER" = "true" ]; then
        local docker_result=$(cat "$temp_dir/docker.log")
        if echo "$docker_result" | grep -q "|"; then
            local name=$(echo "$docker_result" | tail -1 | cut -d'|' -f1)
            local time=$(echo "$docker_result" | tail -1 | cut -d'|' -f2)
            local cpu_avg=$(echo "$docker_result" | tail -1 | cut -d'|' -f3)
            local cpu_max=$(echo "$docker_result" | tail -1 | cut -d'|' -f4)
            [ -n "$time" ] && [ "$time" != "0" ] && update_json "docker_build" "$time" "$cpu_avg" "$cpu_max" && update_csv "docker_build" "$time" "$cpu_avg" "$cpu_max" && print_results "Docker Build" "$time" "$cpu_avg" "$cpu_max"
        fi
    fi

    if [ -f "$temp_dir/maven.log" ] && ! [ "$SKIP_MAVEN" = "true" ]; then
        local maven_result=$(cat "$temp_dir/maven.log")
        if echo "$maven_result" | grep -q "|"; then
            local name=$(echo "$maven_result" | tail -1 | cut -d'|' -f1)
            local time=$(echo "$maven_result" | tail -1 | cut -d'|' -f2)
            local cpu_avg=$(echo "$maven_result" | tail -1 | cut -d'|' -f3)
            local cpu_max=$(echo "$maven_result" | tail -1 | cut -d'|' -f4)
            [ -n "$time" ] && [ "$time" != "0" ] && update_json "maven_build" "$time" "$cpu_avg" "$cpu_max" && update_csv "maven_build" "$time" "$cpu_avg" "$cpu_max" && print_results "Maven Build" "$time" "$cpu_avg" "$cpu_max"
        fi
    fi

    if [ -f "$temp_dir/node.log" ] && ! [ "$SKIP_NODE" = "true" ]; then
        local node_result=$(cat "$temp_dir/node.log")
        if echo "$node_result" | grep -q "|"; then
            local name=$(echo "$node_result" | tail -1 | cut -d'|' -f1)
            local time=$(echo "$node_result" | tail -1 | cut -d'|' -f2)
            local cpu_avg=$(echo "$node_result" | tail -1 | cut -d'|' -f3)
            local cpu_max=$(echo "$node_result" | tail -1 | cut -d'|' -f4)
            [ -n "$time" ] && [ "$time" != "0" ] && update_json "node_build" "$time" "$cpu_avg" "$cpu_max" && update_csv "node_build" "$time" "$cpu_avg" "$cpu_max" && print_results "Node.js Build" "$time" "$cpu_avg" "$cpu_max"
        fi
    fi

    rm -rf "$temp_dir"
    log_success "=== Benchmark parallelo completato ===" "bench"
}

main() {
    parse_args "$@"

    if [ "$MODE" = "quick" ]; then
        NUM_ITERATIONS=1
    fi

    init_results

    check_dependencies

    if [ "$CLEANUP_CACHE" = "true" ]; then
        cleanup
    fi

    run_benchmarks

    log_success "Benchmark completato!" "bench"
    log_info "Risultati: $JSON_FILE" "bench"
    log_info "Log: $LOG_FILE" "bench"
}

main "$@"