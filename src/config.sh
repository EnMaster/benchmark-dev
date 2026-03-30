#!/bin/bash

CONFIG_FILE="$(dirname "$0")/config.sh"

NUM_CORES=$(nproc 2>/dev/null || echo 4)
NUM_ITERATIONS=3
THREADS="${THREADS:-$NUM_CORES}"
MODE="full"
CLEANUP_CACHE=true
OUTPUT_FORMAT="both"

REPO_DOCKER="https://github.com/spring-projects/spring-petclinic.git"
REPO_MAVEN="https://github.com/spring-projects/spring-petclinic.git"
REPO_NODE="https://github.com/facebook/react.git"

WORKSPACE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPOS_DIR="$WORKSPACE_DIR/repos"
RESULTS_DIR="$WORKSPACE_DIR/results"

LOG_FILE="$RESULTS_DIR/benchmark.log"
JSON_FILE="$RESULTS_DIR/results.json"
CSV_FILE="$RESULTS_DIR/results.csv"

DOCKER_IMAGE="openjdk:17-slim"
MAVEN_OPTS="-Xmx1024m"

COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_NC='\033[0m'

log_info() { echo -e "${COLOR_BLUE}[INFO]${COLOR_NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${COLOR_GREEN}[OK]${COLOR_NC} $1" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "${COLOR_YELLOW}[WARN]${COLOR_NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $1" | tee -a "$LOG_FILE"; }

detect_cores() {
    if command -v nproc &>/dev/null; then
        nproc
    elif [ -f /proc/cpuinfo ]; then
        grep -c ^processor /proc/cpuinfo
    elif command -v sysctl &>/dev/null; then
        sysctl -n hw.ncpu
    else
        echo 4
    fi
}

cleanup() {
    log_info "Cleanup in corso..."
    rm -rf "$REPOS_DIR"/* 2>/dev/null
    sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
}

drop_caches() {
    if [ "$(id -u)" = "0" ]; then
        sync && echo 3 > /proc/sys/vm/drop_caches
        log_info "Cache droppata (root)"
    else
        log_warn "Non root, skip drop_caches"
    fi
}

check_dependency() {
    local cmd="$1"
    local package="$2"
    local install_cmd="$3"

    if command -v "$cmd" &>/dev/null; then
        return 0
    fi

    log_warn "$cmd non trovato"
    if [ -n "$package" ] && [ -n "$install_cmd" ]; then
        log_info "Installo $package..."
        eval "$install_cmd" || return 1
    fi
    return 0
}

install_docker() {
    log_info "Installazione Docker..."
    if command -v apt-get &>/dev/null; then
        apt-get update && apt-get install -y docker.io
    elif command -v yum &>/dev/null; then
        yum install -y docker
    fi
}

install_maven() {
    log_info "Installazione Maven..."
    if command -v apt-get &>/dev/null; then
        apt-get update && apt-get install -y maven
    elif command -v yum &>/dev/null; then
        yum install -y maven
    fi
}

install_node() {
    log_info "Installazione Node.js..."
    if command -v apt-get &>/dev/null; then
        apt-get update && apt-get install -y nodejs npm
    elif command -v yum &>/dev/null; then
        yum install -y nodejs npm
    fi
}

install_base_deps() {
    log_info "Installazione dipendenze base..."
    if command -v apt-get &>/dev/null; then
        apt-get update && apt-get install -y wget git curl bc jq
    elif command -v yum &>/dev/null; then
        yum install -y wget git curl bc jq
    fi
}

check_dependencies() {
    local missing=0

    log_info "Verifica dipendenze..."

    check_dependency wget wget "install_base_deps" || ((missing++))
    check_dependency git git "install_base_deps" || ((missing++))
    check_dependency curl curl "install_base_deps" || ((missing++))
    check_dependency bc bc "install_base_deps" || ((missing++))
    check_dependency jq jq "install_base_deps" || ((missing++))
    check_dependency docker docker "install_docker" || ((missing++))
    check_dependency mvn maven "install_maven" || ((missing++))
    check_dependency node node "install_node" || ((missing++))
    check_dependency npm npm "install_node" || ((missing++))

    if [ $missing -gt 0 ]; then
        log_warn "$missing dipendenze mancanti, alcuni test verranno saltati"
    fi

    return 0
}

NUM_CORES=$(detect_cores)
THREADS="${THREADS:-$NUM_CORES}"
