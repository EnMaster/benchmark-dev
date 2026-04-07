#!/bin/bash

BENCHMARK_NAME="Node.js Build"
BENCHMARK_KEY="node_build"

run_node_benchmark() {
    local repo_url="$1"
    local iterations="${2:-3}"
    local workdir="$REPOS_DIR/node_build"

    log_info "=== $BENCHMARK_NAME ==="

    if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
        log_warn "Node.js/npm non disponibile, skip benchmark"
        return 1
    fi

    mkdir -p "$workdir"
    cd "$workdir"

    if [ ! -f "package.json" ]; then
        log_info "Creo progetto Node.js di test..."
        mkdir -p "$workdir/src"
        cat > "$workdir/package.json" << 'EOF'
{
  "name": "benchmark-app",
  "version": "1.0.0",
  "description": "CPU Benchmark",
  "main": "src/index.js",
  "scripts": {
    "build": "node build.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "express": "^4.18.2",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "lodash": "^4.17.21",
    "axios": "^1.4.0",
    "moment": "^2.29.4",
    "underscore": "^1.13.6"
  },
  "devDependencies": {}
}
EOF
            cat > "$workdir/build.js" << 'EOF'
const fs = require('fs');
const path = require('path');

function generateComponent(index) {
    return `
import React from 'react';
import { useState, useEffect } from 'react';

export const Component${index} = ({ data }) => {
    const [state, setState] = useState(data);
    
    useEffect(() => {
        setState(prev => ({ ...prev, timestamp: Date.now() }));
    }, []);

    return (
        <div className="component-${index}">
            <h1>Component ${index}</h1>
            <p>{state.name}</p>
            <ul>
                {state.items && state.items.map((item, i) => (
                    <li key={i}>{item.label}: {item.value}</li>
                ))}
            </ul>
        </div>
    );
};
`;
}

function generateApp() {
    let code = 'import React from "react";\nimport ReactDOM from "react-dom/client";\n\n';
    for (let i = 1; i <= 50; i++) {
        code += generateComponent(i) + "\n";
    }
    code += `\nconst root = ReactDOM.createRoot(document.getElementById('root'));\nroot.render(<div>Benchmark App</div>);\n`;
    return code;
}

const componentsDir = path.join(__dirname, 'src', 'components');
if (!fs.existsSync(componentsDir)) {
    fs.mkdirSync(componentsDir, { recursive: true });
}

const code = generateApp();
fs.writeFileSync(path.join(componentsDir, 'App.js'), code);
console.log('Generated 50 React components');
EOF
    fi

    if [ -f "package.json" ] && [ ! -d "node_modules" ]; then
        log_info "Installo dipendenze Node.js..."
        npm install --legacy-peer-deps &>/dev/null
    fi

    local total_time=0
    local total_cpu_avg=0
    local total_cpu_max=0

    if [ -f "package.json" ]; then
        for i in $(seq 1 $iterations); do
            log_info "Iterazione $i/$iterations..."

            drop_caches
            rm -rf "$workdir/dist" 2>/dev/null

            local build_log="$workdir/build_$i.log"
            local result=$(measure_command "npm run build 2>&1 | tee '$build_log'" "$workdir")
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
    fi

    if [ $iterations -gt 0 ]; then
        local avg_time=$(echo "scale=1; $total_time / $iterations" | bc)
        local avg_cpu=$(echo "scale=1; $total_cpu_avg / $iterations" | bc)
        local max_cpu=$(echo "scale=1; $total_cpu_max / $iterations" | bc)

        echo "$BENCHMARK_NAME|$avg_time|$avg_cpu|$max_cpu"
    fi
}

run_node_benchmark "${REPO_NODE}" "${NUM_ITERATIONS}"
