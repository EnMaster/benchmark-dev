#!/bin/bash

BENCHMARK_NAME="Maven Build"
BENCHMARK_KEY="maven_build"

run_maven_benchmark() {
    local repo_url="$1"
    local threads="${2:-$THREADS}"
    local iterations="${3:-3}"
    local workdir="$REPOS_DIR/maven_build"

    log_info "=== $BENCHMARK_NAME (threads: $threads) ==="

    if ! command -v mvn &>/dev/null; then
        log_warn "Maven non disponibile, skip benchmark"
        return 1
    fi

    mkdir -p "$workdir"
    cd "$workdir"

    if [ ! -f "pom.xml" ]; then
        log_info "Clono repository Maven..."
        git clone --depth 1 "$repo_url" "$workdir" 2>/dev/null || {
            log_info "Clonazione fallita, creo progetto Maven di test..."
            mkdir -p "$workdir/src/main/java/com/example"
            cat > "$workdir/pom.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.example</groupId>
    <artifactId>benchmark-app</artifactId>
    <version>1.0-SNAPSHOT</version>
    <packaging>jar</packaging>
    <properties>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter</artifactId>
            <version>3.1.0</version>
        </dependency>
    </dependencies>
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.11.0</version>
                <configuration>
                    <source>17</source>
                    <target>17</target>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
EOF
            cat > "$workdir/src/main/java/com/example/App.java" << 'JAVA'
package com.example;
public class App {
    public static void main(String[] args) {
        for(int i=0; i<10000000; i++) {}
        System.out.println("Benchmark done");
    }
}
JAVA
        }
    fi

    local total_time=0
    local total_cpu_avg=0
    local total_cpu_max=0

    for i in $(seq 1 $iterations); do
        log_info "Iterazione $i/$iterations..."

        drop_caches

        local build_log="$workdir/build_$i.log"
        local mvn_cmd="mvn clean package -T $threads -DskipTests $MAVEN_OPTS 2>&1 | tee '$build_log'"
        local result=$(measure_command "$mvn_cmd" "$workdir")
        local cpu_avg=$(echo "$result" | cut -d'|' -f1)
        local cpu_max=$(echo "$result" | cut -d'|' -f2)
        local duration=$(echo "$result" | cut -d'|' -f4)

        if [ -n "$duration" ] && [ "$duration" != "0" ]; then
            log_info "=== Output build $i ==="
            tail -20 "$build_log" | while read line; do log_info "  $line"; done
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

run_maven_benchmark "${REPO_MAVEN}" "${THREADS}" "${NUM_ITERATIONS}"
