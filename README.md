# CPU Benchmark v1.0 per Sviluppo Software

> ⚠️ **AVVISO**: Questo progetto è stato scritto interamente in **vibecoding** come esperimento. 
> Usalo a **proprio rischio e pericolo**. Non ci sono garanzie di funzionamento.

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

### Installazione globale (richiede root)
```bash
sudo ./benchmark.sh --install
```

### Installazione utente
```bash
./benchmark.sh --install-user
```

Dopo l'installazione:
```bash
benchmark           # Esegue i benchmark
benchmark --help   # Mostra aiuto
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

# Salta test specifici
./benchmark.sh --skip-docker
./benchmark.sh --skip-maven
./benchmark.sh --skip-node
```

## Dipendenze

Lo strumento installa automaticamente le dipendenze mancanti:

| Tool | Metodo installazione |
|------|---------------------|
| Docker | Ufficiale (download.docker.com) |
| Maven | JDKMAN (sdkman.io) |
| Node.js | NVM (nvm.sh) v20.x LTS |
| Base (git, curl, bc, jq) | apt/yum |

### Installazione manuale
```bash
# Docker (ufficiale)
curl -fsSL https://get.docker.com | sh

# Maven (JDKMAN)
curl -s "https://get.sdkman.io" | bash
source ~/.sdkman/bin/sdkman-init.sh
sdk install maven 3.9.9

# Node.js (nodesource)
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
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

## Note

- Richiede Linux (testato su Ubuntu/Debian)
- Alcuni test vengono saltati se le dipendenze mancano
- `drop_caches` richiede root
- Spazio richiesto: ~2-5GB
- Supporta skip di singoli test con `--skip-docker`, `--skip-maven`, `--skip-node`