#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR" && pwd)"

source "$SCRIPT_DIR/src/config.sh"
source "$SCRIPT_DIR/src/metrics.sh"

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

CPU Benchmark per scenari di sviluppo reali

OPTIONS:
    -m, --mode MODE       Modalità: quick (1 iter) o full (3 iter) [default: full]
    -t, --threads NUM     Numero di thread [default: auto]
    -c, --cleanup         Pulisci cache tra i test [default: true]
    -o, --output FORMAT   Output: cli, json, csv, both [default: both]
    -h, --help            Mostra questo messaggio

ESEMPI:
    $0                      # Esegui tutti i benchmark
    $0 -m quick             # Modalità veloce
    $0 -t 8                 # Usa 8 thread
    $0 -o json              # Solo output JSON

EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
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

    local temp=$(mktemp)
    jq --arg key "$key" \
       --arg time "$time" \
       --arg cpu_avg "$cpu_avg" \
       --arg cpu_max "$cpu_max" \
       --arg cores "$NUM_CORES" \
       --arg threads "$THREADS" \
       '.timestamp = now | .system.cores = ($cores | tonumber) | .system.threads = ($threads | tonumber) | .benchmarks[$key] = {"time": ($time | tonumber), "cpu_avg": ($cpu_avg | tonumber), "cpu_max": ($cpu_max | tonumber)}' \
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

    log_info "Avvio benchmark in modalità: $MODE"
    log_info "Thread configurati: $THREADS"
    log_info "Iterazioni: $mode_iterations"

    get_system_info | tee -a "$LOG_FILE"

    local results=()

    log_info "--- Benchmark 1: Docker Build ---"
    if source "$SCRIPT_DIR/src/docker_bench.sh" 2>&1 | tee -a "$LOG_FILE"; then
        :
    fi

    log_info "--- Benchmark 2: Maven Build ---"
    if source "$SCRIPT_DIR/src/maven_bench.sh" 2>&1 | tee -a "$LOG_FILE"; then
        :
    fi

    log_info "--- Benchmark 3: Node.js Build ---"
    if source "$SCRIPT_DIR/src/node_bench.sh" 2>&1 | tee -a "$LOG_FILE"; then
        :
    fi
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

    log_success "Benchmark completato!"
    log_info "Risultati: $JSON_FILE"
    log_info "Log: $LOG_FILE"
}

main "$@"
