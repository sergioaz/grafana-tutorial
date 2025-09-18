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

# Run ETL simulator locally (for development/testing)
C:\Learn\grafana-tutorial\.venv\Scripts\python.exe etl\etl_simulator.py

# Run ETL metrics exporter locally
C:\Learn\grafana-tutorial\.venv\Scripts\python.exe etl\metrics_exporter.py
```

### Service Access
- Grafana UI: http://localhost:3000 (no login required - anonymous admin access)
- Prometheus UI: http://localhost:9090
- Application: http://localhost:8081
- Database API: http://localhost:8082
- ETL Metrics: http://localhost:8083/metrics
- ETL Health: http://localhost:8083/health

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

# Check ETL metrics
curl http://localhost:8083/metrics

# Check ETL health status
curl http://localhost:8083/health
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

## ETL Process Monitoring

The system includes a complete ETL simulation and monitoring setup that demonstrates real-world data processing monitoring patterns.

### ETL Components
- **etl-simulator**: Simulates file processing at ~10 records/sec with periodic failures (~1/minute)
- **etl-metrics**: Exposes Prometheus metrics from ETL logs via HTTP endpoint (port 8083)
- **ETL Dashboard**: Pre-configured Grafana dashboard for ETL monitoring
- **ETL Alerts**: Automated alerting for ETL failures, low throughput, and health issues

### ETL Metrics Available
- `etl_records_total`: Total records processed
- `etl_files_total`: Total files processed
- `etl_failures_total`: Total processing failures
- `etl_current_rate_records_per_second`: Current processing rate
- `etl_avg_processing_time_seconds`: Average file processing time
- `etl_seconds_since_last_success`: Time since last successful processing
- `etl_errors_by_type_total`: Error counts by failure type
- `etl_health_status`: Overall ETL process health (1=healthy, 0=down)

### ETL Management Commands
```bash
# Start only ETL services
docker compose up -d etl-simulator etl-metrics

# View ETL logs
docker compose logs -f etl-simulator
docker compose logs -f etl-metrics

# Stop ETL services
docker compose stop etl-simulator etl-metrics

# Restart ETL services (useful for testing failure scenarios)
docker compose restart etl-simulator
```

### ETL Development and Testing
```bash
# Run ETL components locally for development
C:\Learn\grafana-tutorial\.venv\Scripts\python.exe etl\etl_simulator.py
C:\Learn\grafana-tutorial\.venv\Scripts\python.exe etl\metrics_exporter.py

# Test metrics endpoint
curl http://localhost:8083/metrics | findstr "etl_"

# Monitor ETL health
while ($true) { curl http://localhost:8083/health; Start-Sleep 10 }
```

### Grafana ETL Dashboard
The ETL dashboard provides:
- **Processing Rate**: Real-time and historical throughput metrics
- **Health Status**: Current ETL process health indicator
- **Error Analysis**: Failure counts and error type distribution
- **Performance Metrics**: Processing times and efficiency trends
- **Activity Timeline**: Success/failure patterns over time

### ETL Alerting
Configured alerts include:
- **Critical**: ETL health check failures (triggers after 2 minutes)
- **Critical**: Metrics endpoint unavailable
- **Warning**: No successful processing in 10 minutes
- **Warning**: High failure rate (multiple failures in 5 minutes)
- **Warning**: Low throughput (below expected rate)
- **Warning**: Excessive processing times

## Troubleshooting

### Common Issues
- **Port already in use**: Check if services are already running with `docker compose ps`
- **Build failures**: Ensure Docker has sufficient memory allocated (recommended 4GB+)
- **Metrics not showing**: Verify Prometheus can reach `app:80/metrics` endpoint
- **Logs not appearing**: Check Promtail configuration and log file permissions
- **ETL metrics not available**: Check that port 8083 is not blocked and etl-metrics container is running
- **ETL simulator not processing**: Verify log file permissions in shared volume and Python dependencies
- **ETL alerts not triggering**: Ensure Grafana alerting is enabled and Prometheus is scraping ETL metrics

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

# Check ETL services
docker compose exec etl-metrics curl -f http://localhost:8083/health
docker compose exec prometheus wget -O- http://etl-metrics:8083/metrics

# Verify ETL log file
docker compose exec etl-simulator ls -la /app/logs/
docker compose exec etl-simulator tail -f /app/logs/etl_process.log
```