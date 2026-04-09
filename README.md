# Node.js Build Benchmark System / Sistema di Benchmark Node.js

---

## English

### Overview

A comprehensive benchmarking system for stress-testing CPU, RAM, and NVMe storage under realistic Node.js build conditions. Automatically generates a heavy Node.js project with TypeScript and Vite, then runs the build while collecting detailed system metrics.

### Features

- **Automatic Project Generation**: Creates a heavy Node.js project with hundreds of modules
- **Multi-metric Monitoring**: Tracks CPU, RAM, and disk I/O during builds
- **Configurable Intensity**: Three presets (low, medium, high)
- **Structured Output**: JSON metrics and summary reports
- **Reproducible**: Deterministic builds for consistent benchmarking

### Quick Start

```bash
cd /root/test
./run-benchmark.sh medium 1
```

### Usage

```bash
./run-benchmark.sh [intensity] [num_runs]
```

#### Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `intensity` | Workload level (low/medium/high) | medium |
| `num_runs` | Number of benchmark runs | 1 |

#### Intensity Settings

| Level | Modules | Files/Module | Expected Duration |
|-------|---------|--------------|-------------------|
| low | 100 | 3 | ~15s |
| medium | 500 | 10 | ~60s |
| high | 1000 | 20 | ~180s |

### Output Files

After running, results are saved to `output/`:

| File | Description |
|------|-------------|
| `summary.json` | Final benchmark results |
| `metrics.jsonl` | Raw time-series metrics |
| `benchmark.log` | Build output log |
| `system-info.txt` | System information |

### Sample Output (summary.json)

```json
{
  "benchmark": {
    "timestamp": "2026-04-09T21:11:30+00:00",
    "intensity": "medium",
    "num_modules": 500,
    "num_files_per_module": 10
  },
  "timing": {
    "project_generation_seconds": 22,
    "dependency_install_seconds": 9,
    "build_seconds": 25,
    "total_seconds": 56
  },
  "metrics": {
    "peak_cpu_percent": 66,
    "avg_cpu_percent": 44,
    "peak_memory_mb": 2671
  },
  "system": {
    "cpu_model": "Intel(R) N100",
    "total_memory_mb": 15769
  }
}
```

### Architecture

#### Scripts

| Script | Purpose |
|--------|---------|
| `run-benchmark.sh` | Main orchestrator |
| `scripts/01-system-info.sh` | Collect system info |
| `scripts/02-generate-project.sh` | Generate heavy project |
| `scripts/03-monitor.sh` | Alternative monitoring (per-process) |
| `scripts/04-continuous-monitor.sh` | Alternative monitoring (system-wide) |

Note: `run-benchmark.sh` uses inline monitoring by default. Scripts 03 and 04 are alternative implementations.

#### Stress Characteristics

- **CPU**: TypeScript compilation + Vite bundling with parallel workers
- **RAM**: Large dependency tree, in-memory transformations
- **NVMe**: Thousands of source files, incremental build artifacts

### Requirements

- Ubuntu (or similar Linux)
- Node.js 18+
- npm 9+
- bash 4+

### Notes

- First run installs dependencies (~9s)
- Build times vary by system hardware
- Peak memory includes Node.js process + system cache

---

## Italiano

### Panoramica

Un sistema di benchmark completo per stress-test di CPU, RAM e storage NVMe in condizioni realistiche di build Node.js. Genera automaticamente un progetto Node.js pesante con TypeScript e Vite, poi esegue il build mentre raccoglie metriche dettagliate del sistema.

### Caratteristiche

- **Generazione Automatica del Progetto**: Crea un progetto Node.js pesante con centinaia di moduli
- **Monitoraggio Multi-metrica**: Traccia CPU, RAM e I/O disco durante i build
- **Intensità Configurabile**: Tre preset (low, medium, high)
- **Output Strutturato**: Metriche JSON e report di riepilogo
- **Riproducibile**: Build deterministici per benchmark consistenti

### Avvio Rapido

```bash
cd /root/test
./run-benchmark.sh medium 1
```

### Utilizzo

```bash
./run-benchmark.sh [intensità] [num_runs]
```

#### Argomenti

| Argomento | Descrizione | Default |
|----------|-------------|---------|
| `intensità` | Livello di carico (low/medium/high) | medium |
| `num_runs` | Numero di esecuzioni del benchmark | 1 |

#### Impostazioni di Intensità

| Livello | Moduli | File/Modulo | Durata Prevista |
|---------|--------|-------------|-----------------|
| low | 100 | 3 | ~15s |
| medium | 500 | 10 | ~60s |
| high | 1000 | 20 | ~180s |

### File di Output

Dopo l'esecuzione, i risultati vengono salvati in `output/`:

| File | Descrizione |
|------|-------------|
| `summary.json` | Risultati finali del benchmark |
| `metrics.jsonl` | Metriche grezze in serie temporale |
| `benchmark.log` | Log dell'output del build |
| `system-info.txt` | Informazioni di sistema |

### Esempio di Output (summary.json)

```json
{
  "benchmark": {
    "timestamp": "2026-04-09T21:11:30+00:00",
    "intensity": "medium",
    "num_modules": 500,
    "num_files_per_module": 10
  },
  "timing": {
    "project_generation_seconds": 22,
    "dependency_install_seconds": 9,
    "build_seconds": 25,
    "total_seconds": 56
  },
  "metrics": {
    "peak_cpu_percent": 66,
    "avg_cpu_percent": 44,
    "peak_memory_mb": 2671
  },
  "system": {
    "cpu_model": "Intel(R) N100",
    "total_memory_mb": 15769
  }
}
```

### Architettura

#### Script

| Script | Funzione |
|--------|----------|
| `run-benchmark.sh` | Orchestratore principale |
| `scripts/01-system-info.sh` | Raccoglie info sistema |
| `scripts/02-generate-project.sh` | Genera progetto pesante |
| `scripts/03-monitor.sh` | Monitoraggio alternativo (per-processo) |
| `scripts/04-continuous-monitor.sh` | Monitoraggio alternativo (sistema) |

Nota: `run-benchmark.sh` utilizza monitoraggio inline di default. Gli script 03 e 04 sono implementazioni alternative.

#### Caratteristiche di Stress

- **CPU**: Compilazione TypeScript + bundling Vite con worker paralleli
- **RAM**: Albero delle dipendenze grande, trasformazioni in memoria
- **NVMe**: Migliaia di file sorgente, artifact di build incrementali

### Requisiti

- Ubuntu (o Linux simile)
- Node.js 18+
- npm 9+
- bash 4+

### Note

- La prima esecuzione installa le dipendenze (~9s)
- I tempi di build variano in base all'hardware del sistema
- Il picco di memoria include il processo Node.js + cache di sistema