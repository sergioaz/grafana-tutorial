# Pure ETL-Only Monitoring Stack 🎯

This configuration provides the **cleanest possible ETL monitoring environment** with only the essential components needed for ETL process monitoring and alerting.

## 🏗️ What's Included (4 Services Only)

| Service | Purpose | Port | Resources |
|---------|---------|------|-----------|
| **prometheus** | Metrics storage & querying | 9090 | ~200MB RAM |
| **grafana** | Dashboards & alerting | 3000 | ~150MB RAM |
| **etl-simulator** | ETL process simulation | - | ~50MB RAM |
| **etl-metrics** | Prometheus metrics exporter | 8083 | ~30MB RAM |

**Total Resources**: ~430MB RAM, 4 containers

## ❌ What's Excluded

- ❌ Go web application
- ❌ Database service  
- ❌ Promtail log collector
- ❌ Loki log aggregation
- ❌ Any unnecessary components

## 🚀 Quick Start

### Option 1: PowerShell Script (Recommended)
```powershell
# Start the stack
.\etl\start-etl-only-monitoring.ps1 -StartStack

# Stop the stack  
.\etl\start-etl-only-monitoring.ps1 -StopStack

# Restart just ETL components
.\etl\start-etl-only-monitoring.ps1 -RestartETL

# Check status
.\etl\start-etl-only-monitoring.ps1 -ShowStatus
```

### Option 2: Docker Compose Direct
```bash
# Start stack
docker compose -f docker-compose-etl-only.yml up -d

# Stop stack
docker compose -f docker-compose-etl-only.yml down

# View logs
docker compose -f docker-compose-etl-only.yml logs -f etl-simulator
```

## 🔄 Architecture Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ETL Simulator│───▶│Log Files    │───▶│ETL Metrics  │───▶│Prometheus   │
│(Processing) │    │(JSON)       │    │Exporter     │    │(Storage)    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                   │
                                                                   ▼
                                                           ┌─────────────┐
                                                           │Grafana      │
                                                           │Dashboard &  │
                                                           │Alerts       │
                                                           └─────────────┘
```

## 📊 ETL Simulation Characteristics

- **Processing Rate**: ~10 records/second (600 records/minute)
- **File Sizes**: 50-500 records per file (randomized)
- **Failure Rate**: ~1 failure per minute (realistic failure scenarios)
- **Error Types**: 5 different realistic error categories
- **Logging**: Structured JSON logs with full processing metrics

## 📈 Available Metrics

| Metric | Type | Purpose |
|--------|------|---------|
| `etl_records_total` | Counter | Total records processed |
| `etl_files_total` | Counter | Total files processed |
| `etl_failures_total` | Counter | Total failures |
| `etl_current_rate_records_per_second` | Gauge | Current processing rate |
| `etl_avg_processing_time_seconds` | Gauge | Average processing time |
| `etl_seconds_since_last_success` | Gauge | Time since last success |
| `etl_health_status` | Gauge | Health indicator (1=up, 0=down) |
| `etl_uptime_seconds` | Gauge | Process uptime |
| `etl_errors_by_type_total` | Counter | Errors by type |

## 🎛️ Pre-configured Dashboard

**ETL Process Monitoring Dashboard** (`http://localhost:3000/d/etl-monitoring`)

### Dashboard Panels:
1. **Processing Rate** - Real-time throughput metrics
2. **Health Status** - Current ETL process health
3. **Time Since Last Success** - Monitoring for stalled processing
4. **Total Failures** - Cumulative error count
5. **Average Processing Time** - Performance monitoring
6. **Cumulative Counts** - Records and files over time
7. **Error Types Distribution** - Failure category breakdown
8. **Processing Activity** - 5-minute increment view

## 🚨 Automated Alerts

### Critical Alerts
- **ETL Process Health Check Failed** (triggers after 2 minutes)
- **ETL Metrics Endpoint Unavailable** (monitoring infrastructure)

### Warning Alerts
- **No ETL Success in 10 Minutes** (stalled processing)
- **High ETL Failure Rate** (multiple failures in 5 minutes)
- **Low Throughput** (processing rate below threshold)
- **Excessive Processing Time** (performance degradation)

## 🔧 Configuration Files

```
├── docker-compose-etl-only.yml          # Main service definitions
├── prometheus/prometheus-etl-only.yml    # ETL-focused Prometheus config
├── grafana/provisioning/
│   ├── datasources/datasources-metrics.yaml  # Prometheus-only datasource
│   ├── dashboards/etl-monitoring.json        # ETL dashboard
│   └── alerting/etl-alerts.yaml             # Alert rules
└── etl/
    ├── start-etl-only-monitoring.ps1    # Management script
    ├── etl_simulator.py                 # ETL process simulator
    └── metrics_exporter.py              # Prometheus metrics exporter
```

## 🛠️ Management Commands

### Service Control
```bash
# Start stack
docker compose -f docker-compose-etl-only.yml up -d

# Stop stack
docker compose -f docker-compose-etl-only.yml down

# Restart ETL components only
docker compose -f docker-compose-etl-only.yml restart etl-simulator etl-metrics

# View service status
docker compose -f docker-compose-etl-only.yml ps
```

### Monitoring Commands
```bash
# Check ETL health
curl http://localhost:8083/health

# View raw metrics
curl http://localhost:8083/metrics | grep etl_

# Monitor logs in real-time
docker compose -f docker-compose-etl-only.yml logs -f etl-simulator

# View Prometheus targets
curl http://localhost:9090/api/v1/targets
```

### Development Commands
```bash
# Run ETL simulator locally (for development)
C:\Learn\grafana-tutorial\.venv\Scripts\python.exe etl\etl_simulator.py

# Run metrics exporter locally (separate terminal)
C:\Learn\grafana-tutorial\.venv\Scripts\python.exe etl\metrics_exporter.py
```

## 📍 Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| **Grafana Home** | http://localhost:3000 | Main interface |
| **ETL Dashboard** | http://localhost:3000/d/etl-monitoring | ETL monitoring |
| **ETL Health** | http://localhost:8083/health | Health check |
| **ETL Metrics** | http://localhost:8083/metrics | Raw metrics |
| **Prometheus** | http://localhost:9090 | Metrics query interface |
| **Prometheus Targets** | http://localhost:9090/targets | Scrape status |

## 🔍 Troubleshooting

### Common Issues

1. **ETL metrics not appearing**
   ```bash
   # Check service status
   docker compose -f docker-compose-etl-only.yml ps etl-metrics
   
   # Verify endpoint
   curl http://localhost:8083/health
   
   # Check Prometheus targets
   curl http://localhost:9090/api/v1/targets
   ```

2. **Dashboard not loading**
   ```bash
   # Check Grafana logs
   docker compose -f docker-compose-etl-only.yml logs grafana
   
   # Verify provisioning
   ls -la grafana/provisioning/dashboards/
   ```

3. **Alerts not triggering**
   ```bash
   # Check alert rules in Grafana
   # Visit: http://localhost:3000/alerting/list
   
   # Verify Prometheus is scraping metrics
   # Visit: http://localhost:9090/targets
   ```

### Performance Optimization

1. **Reduce resource usage**:
   - Lower Grafana log level from `debug` to `info`
   - Adjust Prometheus retention period
   - Reduce ETL processing rate if needed

2. **Increase processing rate**:
   - Modify `records_per_second` in `etl_simulator.py`
   - Adjust failure intervals for different testing scenarios

## 🎯 Use Cases

### Perfect for:
- ✅ **ETL Process Monitoring Demos**
- ✅ **Learning Prometheus/Grafana**
- ✅ **Testing Alert Configurations**
- ✅ **Resource-Constrained Environments**
- ✅ **CI/CD Pipeline Testing**
- ✅ **Educational Workshops**

### Not ideal for:
- ❌ Full microservice observability demos
- ❌ Log analysis demonstrations
- ❌ Complex multi-app monitoring scenarios

## 🚀 Production Considerations

Before using in production:
1. **Add authentication** to Grafana
2. **Configure persistent volumes** for Prometheus data
3. **Set up external alerting** (email, Slack, PagerDuty)
4. **Add resource limits** to Docker services
5. **Implement backup/restore** procedures
6. **Configure proper retention** policies

## 🤝 Contributing

To modify the ETL-only stack:
1. Test changes with `.\etl\start-etl-only-monitoring.ps1 -StartStack`
2. Update this README with any configuration changes
3. Verify dashboard and alerts still work correctly
4. Test with different failure scenarios using `RestartETL`

---

**This configuration provides the cleanest possible ETL monitoring experience with minimal overhead and maximum focus on the ETL process itself.** 🎯