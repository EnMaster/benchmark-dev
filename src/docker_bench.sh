#!/bin/bash

BENCHMARK_NAME="Docker Build"
BENCHMARK_KEY="docker_build"

run_docker_benchmark() {
    local repo_url="$1"
    local iterations="${2:-3}"
    local workdir="$REPOS_DIR/docker_build"

    log_info "=== $BENCHMARK_NAME ==="

    if ! command -v docker &>/dev/null; then
        log_warn "Docker non disponibile, skip benchmark"
        return 1
    fi

    if ! docker info &>/dev/null; then
        log_warn "Docker daemon non in esecuzione, skip benchmark"
        return 1
    fi

    mkdir -p "$workdir"
    cd "$workdir"

    if [ ! -f "Dockerfile" ]; then
        log_info "Creo Dockerfile di test..."
        cat > Dockerfile << 'EOF'
FROM eclipse-temurin:17-jdk

WORKDIR /app

RUN apt-get update && \
    apt-get install -y maven && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src ./src
RUN mvn package -DskipTests

CMD ["java", "-jar", "target/petclinic.jar"]
EOF
    fi

    local total_time=0
    local total_cpu_avg=0
    local total_cpu_max=0

    for i in $(seq 1 $iterations); do
        log_info "Iterazione $i/$iterations..."

        drop_caches
        docker system prune -f &>/dev/null || true

        local build_log="$workdir/build_$i.log"
        local result=$(measure_command "docker build --no-cache -t benchmark/petclinic . 2>&1 | tee '$build_log'" "$workdir")
        local cpu_avg=$(echo "$result" | cut -d'|' -f1)
        local cpu_max=$(echo "$result" | cut -d'|' -f2)
        local duration=$(echo "$result" | cut -d'|' -f4)

        if [ -n "$duration" ] && [ "$duration" != "0" ]; then
            log_info "=== Output build $i ==="
            cat "$build_log" | head -30 | while read line; do log_info "  $line"; done
            log_success "Iterazione $i completata: ${duration}s, CPU: ${cpu_avg}%"
            total_time=$(echo "$total_time + $duration" | bc)
            total_cpu_avg=$(echo "$total_cpu_avg + $cpu_avg" | bc)
            total_cpu_max=$(echo "$total_cpu_max + $cpu_max" | bc)
        else
            log_warn "Iterazione $i fallita"
        fi
    done

    if [ $iterations -gt 0 ]; then
        local avg_time=$(echo "scale=1; $total_time / $iterations" | bc)
        local avg_cpu=$(echo "scale=1; $total_cpu_avg / $iterations" | bc)
        local max_cpu=$(echo "scale=1; $total_cpu_max / $iterations" | bc)

        echo "$BENCHMARK_NAME|$avg_time|$avg_cpu|$max_cpu"
    fi
}

run_docker_benchmark "${REPO_DOCKER}" "${NUM_ITERATIONS}"
