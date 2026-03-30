# CPU Benchmark per Sviluppo Software

Strumento per misurare le performance CPU attraverso scenari reali di build.

## Perché questi workload?

### Docker Build
- **Reale**: Building di un'applicazione Spring Boot reale
- **Multi-stage**: Utilizza apt-get, maven, multi-thread
- **Stress**: Scarica dipendenze, compila codice, crea layer

### Maven Build
- **Reale**: Progetto Spring PetClinic (production-grade)
- **Multi-core**: `-T 1C` usa tutti i core disponibili
- **Dipendenze**: 50+ dipendenze Maven, download e compilazione

### Node.js Build
- **Reale**: Build di React (npm install + build)
- **I/O intensive**: Download npm packages
- **CPU intensive**: Build/bundling

## Installazione

```bash
git clone <repo>
cd benchmark-cpu
chmod +x benchmark.sh
```

## Utilizzo

```bash
# Modalità full (default)
./benchmark.sh

# Modalità quick (1 iterazione)
./benchmark.sh --mode quick

# Thread manuali
./benchmark.sh --threads 8

# Solo output JSON
./benchmark.sh --output json
```

## Output

### CLI
```
[Docker Build]
  Tempo:     120.5s
  CPU media: 88%
  CPU max:   100%

[Maven Build]
  Tempo:     95.2s
  CPU media: 92%
```

### JSON (`results/results.json`)
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "system": {
    "cores": 8,
    "threads": 8,
    "memory": "16GB",
    "os": "Ubuntu 22.04"
  },
  "benchmarks": {
    "docker_build": {
      "time": 120.5,
      "cpu_avg": 88,
      "cpu_max": 100
    },
    "maven_build": {
      "time": 95.2,
      "cpu_avg": 92,
      "cpu_max": 100
    }
  }
}
```

## Dipendenze

- `docker` (opzionale)
- `maven` (opzionale)
- `node` + `npm` (opzionale)
- `bc`, `jq` (richiesti)

Installazione automatica su Ubuntu/Debian:
```bash
apt-get install bc jq maven docker.io nodejs npm
```

## Note

- Richiede Linux (testato su Ubuntu/Debian)
- Alcuni test vengono saltati se le dipendenze mancano
- `drop_caches` richiede root
- Spazio richiesto: ~2-5GB
