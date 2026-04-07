#!/bin/bash

CONFIG_FILE="$(dirname "$0")/config.sh"

NUM_CORES=$(nproc 2>/dev/null || echo 4)
NUM_ITERATIONS=3
THREADS="${THREADS:-$NUM_CORES}"
MODE="full"
CLEANUP_CACHE=true
OUTPUT_FORMAT="both"
INSTALL_MODE=false
SKIP_DOCKER="${SKIP_DOCKER:-false}"
SKIP_MAVEN="${SKIP_MAVEN:-false}"
SKIP_NODE="${SKIP_NODE:-false}"

REPO_DOCKER="https://github.com/spring-projects/spring-petclinic.git"
REPO_MAVEN="https://github.com/spring-projects/spring-petclinic.git"
REPO_NODE="https://github.com/facebook/react.git"

WORKSPACE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPOS_DIR="$WORKSPACE_DIR/repos"
RESULTS_DIR="$WORKSPACE_DIR/results"
CONFIG_DIR="${HOME}/.config/benchmark"

LOG_FILE="$RESULTS_DIR/benchmark.log"
JSON_FILE="$RESULTS_DIR/results.json"
CSV_FILE="$RESULTS_DIR/results.csv"

DOCKER_IMAGE="openjdk:17-slim"
MAVEN_OPTS="-Xmx1024m"

COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_NC='\033[0m'

log_info() { echo -e "${COLOR_BLUE}[INFO]${COLOR_NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${COLOR_GREEN}[OK]${COLOR_NC} $1" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "${COLOR_YELLOW}[WARN]${COLOR_NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $1" | tee -a "$LOG_FILE"; }
log_step() { echo -e "${COLOR_CYAN}[STEP]${COLOR_NC} $1" | tee -a "$LOG_FILE"; }

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

install_base_deps() {
    log_info "Installazione dipendenze base..."
    if command -v apt-get &>/dev/null; then
        apt-get update && apt-get install -y wget git curl bc jq ca-certificates gnupg lsb-release
    elif command -v yum &>/dev/null; then
        yum install -y wget git curl bc jq
    fi
}

install_docker_official() {
    log_info "Installazione Docker (metodo ufficiale)..."
    
    if command -v docker &>/dev/null; then
        log_info "Docker già installato: $(docker --version)"
        return 0
    fi

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            debian|ubuntu|pop)
                log_step "Aggiungo repository Docker per $ID..."
                mkdir -p /etc/apt/keyrings
                curl -fsSL "https://download.docker.com/linux/$ID/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || {
                    log_warn "Impossibile aggiungere GPG key, provo metodo alternativo..."
                    wget -qO- "https://download.docker.com/linux/$ID/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                }
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID ${VERSION_CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                apt-get update
                apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                ;;
            fedora|rhel|centos)
                log_step "Aggiungo repository Docker per $ID..."
                dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
                dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                ;;
            *)
                log_warn "OS non supportato per installazione Docker automatica: $ID"
                return 1
                ;;
        esac
    fi

    if command -v docker &>/dev/null; then
        log_success "Docker installato: $(docker --version)"
    else
        log_error "Installazione Docker fallita"
        return 1
    fi
}

install_sdkman() {
    if [ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
        log_info "SDKMAN già installato"
        export ZSH_VERSION="5.8"
        source "$HOME/.sdkman/bin/sdkman-init.sh"
        return 0
    fi

    log_info "Installazione SDKMAN..."
    if [ "$INSTALL_MODE" = "true" ] && [ "$(id -u)" != "0" ]; then
        log_step "Installo SDKMAN per l'utente corrente..."
        curl -s "https://get.sdkman.io" | bash
        export ZSH_VERSION="5.8"
        source "$HOME/.sdkman/bin/sdkman-init.sh"
    else
        log_warn "SDKMAN richiede installazione interattiva o privilegi root"
        return 1
    fi
}

install_maven_jdkman() {
    log_info "Installazione Maven tramite JDKMAN..."

    if [ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
        export ZSH_VERSION="5.8"
        source "$HOME/.sdkman/bin/sdkman-init.sh"
    else
        install_sdkman || {
            log_warn "SDKMAN non disponibile, installo Maven dai repo..."
            install_maven_apt
            return $?
        }
    fi

    if command -v mvn &>/dev/null; then
        log_info "Maven già installato: $(mvn --version | head -1)"
        return 0
    fi

    log_step "Installo Maven 3.9.x tramite SDKMAN..."
    export ZSH_VERSION="5.8"
    sdk install maven 3.9.9 || sdk install maven 3.9.6 || sdk install maven 3.9.0 || {
        log_warn "Installazione Maven tramite SDKMAN fallita"
        return 1
    }

    if command -v mvn &>/dev/null; then
        log_success "Maven installato: $(mvn --version | head -1)"
    else
        log_error "Installazione Maven fallita"
        return 1
    fi
}

install_maven_apt() {
    log_info "Installazione Maven (fallback apt)..."
    if command -v apt-get &>/dev/null; then
        apt-get update && apt-get install -y maven
    elif command -v yum &>/dev/null; then
        yum install -y maven
    fi
}

install_nvm() {
    if [ -d "$HOME/.nvm" ]; then
        log_info "NVM già installato: $(ls -la $HOME/.nvm 2>/dev/null | head -1)"
        return 0
    fi

    log_info "Installazione NVM..."
    log_step "Scarico e installo NVM..."
    
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh" | bash
    
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if [ -d "$HOME/.nvm" ]; then
        log_success "NVM installato"
    else
        log_error "Installazione NVM fallita"
        return 1
    fi
}

install_node_nvm() {
    log_info "Installazione Node.js tramite NVM..."
    
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 2>/dev/null || {
        if [ -f "$HOME/.bashrc" ]; then
            log_info "Carico NVM da bashrc..."
            source "$HOME/.bashrc" 2>/dev/null
        fi
    }
    
    if ! command -v nvm &>/dev/null; then
        install_nvm || return 1
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi
    
    if command -v node &>/dev/null; then
        log_info "Node.js già installato: $(node --version)"
        return 0
    fi
    
    log_step "Installo Node.js 20.x LTS..."
    nvm install 20
    nvm use 20
    nvm alias default 20
    
    if command -v node &>/dev/null; then
        log_success "Node.js installato: $(node --version)"
        log_success "npm versione: $(npm --version)"
    else
        log_error "Installazione Node.js fallita"
        return 1
    fi
}

check_dependency() {
    local cmd="$1"
    local install_fn="$2"

    if command -v "$cmd" &>/dev/null; then
        return 0
    fi

    log_warn "$cmd non trovato"
    if [ -n "$install_fn" ]; then
        $install_fn
        return $?
    fi
    return 1
}

check_dependencies() {
    local missing=0

    log_info "Verifica dipendenze..."

    check_dependency wget install_base_deps || ((missing++))
    check_dependency git install_base_deps || ((missing++))
    check_dependency curl install_base_deps || ((missing++))
    check_dependency bc install_base_deps || ((missing++))
    check_dependency jq install_base_deps || ((missing++))

    if [ "$SKIP_DOCKER" != "true" ]; then
        check_dependency docker install_docker_official || ((missing++))
    fi
    
    if [ "$SKIP_MAVEN" != "true" ]; then
        check_dependency mvn install_maven_jdkman || ((missing++))
    fi
    
    if [ "$SKIP_NODE" != "true" ]; then
        check_dependency node install_node_nvm || ((missing++))
    fi

    if [ $missing -gt 0 ]; then
        log_warn "$missing dipendenze mancanti, alcuni test verranno saltati"
    fi

    return 0
}

do_install() {
    log_info "=== INSTALLAZIONE BENCHMARK v1.0 ==="
    
    local target_dir="${1:-/usr/local/bin}"
    local config_dir="${2:-$CONFIG_DIR}"
    
    if [ "$(id -u)" != "0" ]; then
        target_dir="$HOME/.local/bin"
        log_warn "Non root, installo in $target_dir"
    fi

    log_step "Creo directory..."
    mkdir -p "$target_dir"
    mkdir -p "$config_dir"
    mkdir -p "$config_dir/src"
    mkdir -p "$REPOS_DIR"
    mkdir -p "$RESULTS_DIR"

    log_step "Copio file..."
    local script_path="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    cp -r "$script_path/src/"* "$config_dir/src/"
    cp "$script_path/benchmark.sh" "$target_dir/benchmark"
    chmod +x "$target_dir/benchmark"

    log_step "Configuro PATH..."
    if [ -f "$HOME/.bashrc" ] && ! grep -q "benchmark" "$HOME/.bashrc"; then
        echo "export PATH=\"\$PATH:$target_dir\"" >> "$HOME/.bashrc"
    fi
    if [ -f "$HOME/.zshrc" ] && ! grep -q "benchmark" "$HOME/.zshrc"; then
        echo "export PATH=\"\$PATH:$target_dir\"" >> "$HOME/.zshrc"
    fi

    log_step "Aggiorno config per utilizzo installed..."
    cat > "$config_dir/config_installed.sh" << 'EOF'
SCRIPT_DIR="$HOME/.config/benchmark"
WORKSPACE_DIR="$HOME/.benchmark"
export SCRIPT_DIR WORKSPACE_DIR
REPOS_DIR="$WORKSPACE_DIR/repos"
RESULTS_DIR="$WORKSPACE_DIR/results"
CONFIG_DIR="$HOME/.config/benchmark"
LOG_FILE="$RESULTS_DIR/benchmark.log"
JSON_FILE="$RESULTS_DIR/results.json"
CSV_FILE="$RESULTS_DIR/results.csv"
EOF

    log_success "Installazione completata!"
    echo ""
    echo "Esegui: benchmark"
    echo "oppure: $target_dir/benchmark"
    echo ""
}

NUM_CORES=$(detect_cores)
THREADS="${THREADS:-$NUM_CORES}"