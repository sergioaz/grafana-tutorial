# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Overview

This is a complete observability stack tutorial environment featuring a Go web application with full monitoring capabilities. The setup demonstrates modern observability practices using Grafana, Prometheus, and Loki.

## Architecture

The system consists of 6 containerized services:

- **app**: Go web application (Hacker News-like interface) exposing metrics on port 8081
- **db**: Database service (grafana/tns-db) for application persistence on port 8082
- **prometheus**: Metrics collection and storage on port 9090
- **loki**: Log aggregation system on port 3100
- **promtail**: Log collection agent that forwards logs to Loki
- **grafana**: Visualization and dashboards on port 3000 (admin access enabled by default)

### Data Flow
1. Go app serves HTTP requests and logs to `/var/log/tns-app.log`
2. Prometheus scrapes app metrics every 5s from `app:80/metrics`
3. Promtail tails application logs and sends to Loki
4. Grafana queries both Prometheus (metrics) and Loki (logs) for visualization

## Key Commands

### Environment Setup
```bash
# Start the complete observability stack
docker compose up -d

# Stop all services
docker compose down

# View logs from all services
docker compose logs -f

# View logs from specific service
docker compose logs -f app
```

### Development
```bash
# Build the Go application locally (requires Go installed)
cd app
go mod download
go build -o app .

# Build Docker image for the app service
docker compose build app

# Run log simulator (requires Python venv activation)
C:\Learn\grafana-tutorial\.venv\Scripts\python.exe app\loki\web-server-logs-simulator.py
```

### Service Access
- Grafana UI: http://localhost:3000 (no login required - anonymous admin access)
- Prometheus UI: http://localhost:9090
- Application: http://localhost:8081
- Database API: http://localhost:8082

### Testing and Monitoring
```bash
# Test application health
curl http://localhost:8081

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Test database connection
curl http://localhost:8082

# Generate sample traffic
curl -X POST http://localhost:8081/post -d "title=Test&url=http://example.com"
```

## Development Workflows

### Working with the Go Application
- Main application code: `app/main.go`
- HTML template: `app/index.html.tmpl`  
- Dependencies: `app/go.mod`
- The app expects database URLs as command line arguments
- Logs structured output suitable for Loki parsing

### Adding Monitoring
- **Metrics**: App uses `github.com/weaveworks/common/server` which automatically exposes Prometheus metrics
- **Logging**: Uses structured logging via `github.com/go-kit/kit/log` 
- **Tracing**: Jaeger tracing enabled via `JAEGER_AGENT_HOST` environment variable

### Grafana Configuration
- Datasources auto-provisioned from `grafana/provisioning/datasources/datasources.yaml`
- Prometheus datasource: `http://prometheus:9090`
- TestData datasource included for demo purposes
- Anonymous access configured with Admin role for tutorial purposes

### Prometheus Configuration
- Scrape configuration: `prometheus/prometheus.yml`
- App metrics scraped every 5 seconds from `app:80`
- Self-monitoring enabled for Prometheus metrics

## Project Structure
```
├── app/                    # Go web application
│   ├── main.go            # Main application logic
│   ├── go.mod             # Go module dependencies
│   ├── Dockerfile         # Container build definition
│   ├── index.html.tmpl    # HTML template
│   └── loki/              # Log generation tools
│       └── web-server-logs-simulator.py
├── docker-compose.yml     # Multi-service orchestration
├── grafana/
│   └── provisioning/      # Grafana auto-configuration
│       └── datasources/
├── prometheus/
│   └── prometheus.yml     # Metrics scraping configuration
└── .venv/                 # Python virtual environment
    └── Scripts/
        └── python.exe     # Python interpreter for log simulator
```

## Environment Notes for WARP

- **Docker Required**: This project is Docker-centric. Ensure Docker Desktop is running
- **Port Conflicts**: Check that ports 3000, 3100, 8081, 8082, 9090 are available
- **Python Environment**: Use the venv at `C:\Learn\grafana-tutorial\.venv\Scripts\python.exe` for Python scripts
- **Go Development**: Go toolchain not required for Docker-based development, but useful for local testing
- **Network**: All services communicate via the `grafana` Docker network
- **Data Persistence**: Application data stored in `app_data` Docker volume
- **Security**: Login disabled for tutorial purposes - anonymous admin access enabled

## Troubleshooting

### Common Issues
- **Port already in use**: Check if services are already running with `docker compose ps`
- **Build failures**: Ensure Docker has sufficient memory allocated (recommended 4GB+)
- **Metrics not showing**: Verify Prometheus can reach `app:80/metrics` endpoint
- **Logs not appearing**: Check Promtail configuration and log file permissions

### Debug Commands
```bash
# Check service health
docker compose ps

# Inspect service logs
docker compose logs prometheus
docker compose logs loki
docker compose logs grafana

# Verify network connectivity
docker compose exec app wget -O- http://db:80
docker compose exec prometheus wget -O- http://app:80/metrics
```