# Streamlined Metrics-Only Monitoring Stack

This configuration provides a **focused metrics monitoring approach** that excludes log aggregation components (Promtail/Loki) in favor of direct Prometheus metrics collection.

## 🎯 Why Use the Streamlined Approach?

### ✅ Advantages
- **Simplified Architecture**: Fewer services to manage and troubleshoot
- **Better Performance**: No log parsing overhead
- **Direct Metrics**: Real-time metrics without log processing delays  
- **Focused ETL Monitoring**: Purpose-built for data processing monitoring
- **Lower Resource Usage**: Reduced memory and CPU requirements
- **Easier Alerting**: Direct metric-based alerts vs log pattern matching

### ❌ Trade-offs
- No centralized log searching/analysis through Grafana
- ETL troubleshooting requires direct log file access
- Less comprehensive observability (metrics-only vs metrics + logs)

## 🚀 Quick Start

### Option 1: PowerShell Script (Recommended)
```powershell
.\etl\start-metrics-monitoring.ps1 -FullStack -UseStreamlinedConfig
```

### Option 2: Docker Compose Direct
```bash
docker compose -f docker-compose-metrics.yml up -d
```

## 📋 Service Architecture

| Service | Purpose | Port | Metrics Source |
|---------|---------|------|----------------|
| **grafana** | Visualization & Alerting | 3000 | Prometheus |
| **prometheus** | Metrics Storage | 9090 | Scrapes all metrics |
| **app** | Go Web Application | 8081 | Built-in metrics endpoint |
| **db** | Database Service | 8082 | N/A |
| **etl-simulator** | ETL Process Simulation | - | Logs to shared volume |
| **etl-metrics** | ETL Metrics Exporter | 8083 | Custom HTTP endpoint |

## 🔄 Data Flow

```
┌─────────────────┐    ┌──────────────┐    ┌────────────┐    ┌──────────┐
│  ETL Simulator  │───▶│ Log Files    │───▶│ ETL Metrics│───▶│Prometheus│
│                 │    │ (JSON)       │    │ Exporter   │    │          │
└─────────────────┘    └──────────────┘    └────────────┘    └──────────┘
                                                                    │
┌─────────────────┐    ┌──────────────┐                            │
│  Go App         │───▶│ Built-in     │───────────────────────────┤
│                 │    │ /metrics     │                            │
└─────────────────┘    └──────────────┘                            ▼
                                                              ┌──────────┐
                                                              │ Grafana  │
                                                              │Dashboard │
                                                              │& Alerts  │
                                                              └──────────┘
```

## 📊 Available Dashboards

### ETL Process Monitoring
- **URL**: http://localhost:3000/d/etl-monitoring
- **Metrics**: Processing rates, error analysis, health status
- **Alerts**: Automated monitoring for failures and performance issues

### Prometheus Targets  
- **URL**: http://localhost:9090/targets
- **Purpose**: Verify all metrics endpoints are being scraped

## 🔧 Configuration Files

| File | Purpose |
|------|---------|
| `docker-compose-metrics.yml` | Streamlined service definitions |
| `grafana/provisioning/datasources/datasources-metrics.yaml` | Prometheus-only data sources |
| `prometheus/prometheus.yml` | Metrics scraping configuration |
| `etl/start-metrics-monitoring.ps1` | Automated startup script |

## 🛠️ Management Commands

### Service Control
```bash
# Start streamlined stack
docker compose -f docker-compose-metrics.yml up -d

# Stop specific services
docker compose -f docker-compose-metrics.yml stop etl-simulator etl-metrics

# Restart ETL components
docker compose -f docker-compose-metrics.yml restart etl-simulator

# View service status
docker compose -f docker-compose-metrics.yml ps

# Stop everything
docker compose -f docker-compose-metrics.yml down
```

### Monitoring Commands
```bash
# Check ETL health
curl http://localhost:8083/health

# View ETL metrics
curl http://localhost:8083/metrics | grep etl_

# Monitor ETL logs directly
docker compose -f docker-compose-metrics.yml logs -f etl-simulator

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets
```

## 🔍 Troubleshooting

### ETL Metrics Not Showing
1. **Check ETL metrics service**: `docker compose -f docker-compose-metrics.yml ps etl-metrics`
2. **Verify endpoint**: `curl http://localhost:8083/health`
3. **Check Prometheus targets**: Visit http://localhost:9090/targets
4. **View ETL logs**: `docker compose -f docker-compose-metrics.yml logs etl-simulator`

### Grafana Dashboard Issues
1. **Check datasource**: Ensure Prometheus datasource is configured
2. **Verify metrics**: Visit http://localhost:9090/graph and search for `etl_`
3. **Check provisioning**: Ensure dashboard JSON is valid

### Performance Issues
1. **Monitor resource usage**: `docker stats`
2. **Check ETL processing rate**: Visit http://localhost:8083/health
3. **Verify no resource contention**: Stop unnecessary services

## 🔄 Switching Between Configurations

### To Streamlined (Current)
```bash
# Stop current stack
docker compose down

# Start streamlined stack  
docker compose -f docker-compose-metrics.yml up -d
```

### Back to Full Stack (with logs)
```bash
# Stop streamlined stack
docker compose -f docker-compose-metrics.yml down

# Restore original datasources
git checkout -- grafana/provisioning/datasources/datasources.yaml

# Start full stack
docker compose up -d
```

## 📈 Metrics Available

All metrics from the full ETL monitoring system are available:
- `etl_records_total` - Total records processed
- `etl_files_total` - Total files processed  
- `etl_failures_total` - Total processing failures
- `etl_current_rate_records_per_second` - Current processing rate
- `etl_health_status` - ETL process health (1=healthy, 0=down)
- Plus all Go application metrics from `/metrics` endpoint

## 🚀 Production Considerations

For production deployments:
1. **Add resource limits** to Docker services
2. **Configure Prometheus retention** policies
3. **Set up external alerting** (email, Slack, etc.)
4. **Implement proper logging** alongside metrics
5. **Add authentication** to Grafana
6. **Monitor Prometheus storage** usage

## 🤝 Contributing

When modifying the streamlined configuration:
1. Test both configurations work correctly
2. Update this README with any changes
3. Ensure dashboard compatibility with both setups
4. Document any new metrics or alerts added