# ETL Process Monitoring System

This directory contains a complete ETL (Extract, Transform, Load) simulation and monitoring system designed to demonstrate real-world data processing monitoring patterns using Prometheus, Grafana, and Python.

## Overview

The ETL system simulates a realistic data processing pipeline with:
- File processing at approximately **10 records per second**
- Periodic failures (~1 failure per minute) with various realistic error types
- Comprehensive metrics collection and monitoring
- Real-time dashboards and alerting

## Components

### 1. ETL Simulator (`etl_simulator.py`)
- Simulates processing files of varying sizes (50-500 records each)
- Maintains target throughput of ~10 records/second
- Introduces controlled failures with realistic error scenarios
- Generates structured JSON logs with timestamps and processing metrics
- Includes graceful shutdown handling

### 2. Metrics Exporter (`metrics_exporter.py`)
- Reads ETL logs in real-time and converts to Prometheus metrics
- Exposes HTTP endpoint at port 8083 for metrics scraping
- Provides health check endpoint
- Tracks processing rates, error types, and performance statistics

### 3. Docker Integration
- Dockerfile for containerized deployment
- Docker Compose integration with the monitoring stack
- Shared volume for log files between simulator and exporter
- Health checks and restart policies

### 4. Monitoring & Alerting
- Pre-configured Grafana dashboard with comprehensive ETL monitoring
- Prometheus alert rules for various failure scenarios
- Real-time performance metrics and error analysis

## Quick Start

### Option 1: Use the PowerShell Startup Script
```powershell
# Start complete monitoring stack + ETL
.\etl\start-etl-monitoring.ps1 -FullStack

```

### Option 2: Manual Docker Compose
```bash
# Start complete stack
docker compose up -d

# Start only ETL services
docker compose up -d etl-simulator etl-metrics
```

### Option 3: Local Development
```bash
# Run simulator locally
C:\Learn\grafana-tutorial\.venv\Scripts\python.exe etl\etl_simulator.py

# Run metrics exporter locally (in separate terminal)
C:\Learn\grafana-tutorial\.venv\Scripts\python.exe etl\metrics_exporter.py
```

## Monitoring Access

| Component | URL | Description |
|-----------|-----|-------------|
| ETL Dashboard | http://localhost:3000/d/etl-monitoring | Comprehensive ETL monitoring dashboard |
| ETL Metrics | http://localhost:8083/metrics | Prometheus metrics endpoint |
| ETL Health | http://localhost:8083/health | Health check and status |
| Grafana Home | http://localhost:3000 | Main Grafana interface |
| Prometheus | http://localhost:9090 | Prometheus query interface |

## Available Metrics

| Metric Name | Type | Description |
|-------------|------|-------------|
| `etl_records_total` | Counter | Total number of records processed |
| `etl_files_total` | Counter | Total number of files processed |
| `etl_failures_total` | Counter | Total number of processing failures |
| `etl_current_rate_records_per_second` | Gauge | Current processing rate |
| `etl_avg_processing_time_seconds` | Gauge | Average file processing time |
| `etl_seconds_since_last_success` | Gauge | Time since last successful processing |
| `etl_seconds_since_last_failure` | Gauge | Time since last failure |
| `etl_errors_by_type_total` | Counter | Error counts by failure type |
| `etl_health_status` | Gauge | Overall ETL process health (1=healthy, 0=down) |
| `etl_uptime_seconds` | Gauge | ETL process uptime |

## Alert Rules

The system includes pre-configured alerts for:

### Critical Alerts
- **ETL Process Health Check Failed**: Triggers when health status is 0 for >2 minutes
- **ETL Metrics Endpoint Unavailable**: Triggers when metrics endpoint is unreachable

### Warning Alerts
- **No ETL Success in 10 Minutes**: Triggers when no successful processing for >10 minutes
- **High ETL Failure Rate**: Triggers on multiple failures within 5 minutes
- **ETL Processing Rate Below Threshold**: Triggers when throughput drops significantly
- **ETL Excessive Processing Time**: Triggers when processing times are unusually high

## Error Types Simulated

The simulator generates realistic error scenarios:
- `connection_timeout`: Database or network connection issues
- `corrupt_file_format`: Invalid or corrupted input files
- `disk_space_insufficient`: Storage capacity issues
- `database_lock_timeout`: Database locking conflicts
- `invalid_data_schema`: Data validation failures

## Management Commands

```bash
# View real-time logs
docker compose logs -f etl-simulator
docker compose logs -f etl-metrics

# Restart ETL simulator (useful for testing failure recovery)
docker compose restart etl-simulator

# Stop ETL services
docker compose stop etl-simulator etl-metrics

# Check service health
docker compose ps

# Test endpoints
curl http://localhost:8083/health
curl http://localhost:8083/metrics
```

## Development

### Log Format
The ETL simulator generates structured JSON logs:
```json
{
  "timestamp": "2025-01-18T04:00:00Z",
  "message": "file_processing_completed",
  "total_records": 1250,
  "total_files": 5,
  "total_failures": 1,
  "file_id": "file_000005",
  "records_processed": 250,
  "processing_time": 25.3,
  "current_rate": 9.88
}
```

### Customizing the Simulator
Key parameters in `etl_simulator.py`:
- `records_per_second`: Target processing rate (default: 10)
- `failure_interval`: Time between simulated failures (default: 60 seconds)
- File size range: 50-500 records per file
- Processing time variance: ±20% of calculated time

### Adding New Metrics
To add custom metrics:
1. Update log output in `etl_simulator.py`
2. Add metric parsing in `metrics_exporter.py`
3. Update dashboard queries in `grafana/provisioning/dashboards/etl-monitoring.json`

## Files Structure

```
etl/
├── README.md                     # This file
├── etl_simulator.py             # Main ETL simulation logic
├── metrics_exporter.py          # Prometheus metrics exporter
├── requirements.txt             # Python dependencies
├── Dockerfile.etl               # Container build definition
├── docker-compose.etl.yml       # Standalone ETL compose file
├── start-etl-monitoring.ps1     # PowerShell startup script
└── etl_process.log              # Generated log file (when running locally)
```

## Troubleshooting

### Common Issues

1. **Port 8083 already in use**
   ```bash
   netstat -ano | findstr :8083
   # Kill process using the port if needed
   ```

2. **ETL metrics not appearing in Prometheus**
   - Verify etl-metrics container is running: `docker compose ps etl-metrics`
   - Check Prometheus targets: http://localhost:9090/targets
   - Verify network connectivity: `docker compose exec prometheus wget -O- http://etl-metrics:8083/metrics`

3. **Log file not found errors**
   - Check volume mount: `docker compose exec etl-simulator ls -la /app/logs/`
   - Verify file permissions in shared volume

4. **Dashboard not loading**
   - Ensure Grafana provisioning volumes are mounted correctly
   - Check Grafana logs: `docker compose logs grafana`
   - Verify dashboard file syntax is valid JSON

### Debug Commands

```bash
# Check ETL service logs
docker compose logs etl-simulator | tail -20

# Verify metrics endpoint
curl -s http://localhost:8083/metrics | grep etl_ | head -10

# Test log file access
docker compose exec etl-simulator cat /app/logs/etl_process.log | tail -5

# Monitor health status
while true; do curl -s http://localhost:8083/health | python -m json.tool; sleep 5; done
```

## Contributing

When modifying the ETL system:
1. Test locally first using the Python venv
2. Update relevant documentation
3. Verify Docker build: `docker compose build etl-simulator etl-metrics`
4. Test alert conditions by simulating failures
5. Update dashboard if new metrics are added

## Performance Notes

- The system is designed for development/demo purposes
- In production, consider using proper log aggregation (e.g., Filebeat, Fluentd)
- Metrics retention and cardinality should be monitored in production environments
- Consider implementing circuit breakers and backoff strategies for real systems